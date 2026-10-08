// VoiceGen: makes the app's spoken clips as MP3s.
//
// Two engines; each voice file picks one with "engine":
//   piper  free, offline, no account (default). Voice "Cori", public domain.
//          Needs tools/VoiceGen/piper/ (see README.md).
//   azure  Azure Neural TTS, Indian English, pure phonics sounds.
//          Needs AZURE_SPEECH_KEY (and AZURE_SPEECH_REGION) set on this PC.
//
// Run from the project folder (the one with pubspec.yaml):
//   dotnet run --project tools/VoiceGen              make new or changed clips
//   dotnet run --project tools/VoiceGen -- --dry-run  show what would be said
//   dotnet run --project tools/VoiceGen -- --force    remake every clip
//
// What it reads and writes:
//   tools/VoiceGen/app_prompts.json  -> assets/audio/voice/<name>.mp3
//   content/<pack>/voice.json        -> content/<pack>/audio/<item>_<clip>.mp3,
//                                       and the "audio" map of each item in pack.json
//
// Clip texts are templates: {field} is filled from the pack item,
// {count} counts up to the item's number ("One, two, three"), and a part in
// [square brackets] is left out when a field inside it is empty.
// Unchanged clips are skipped (tools/VoiceGen/cache.json).

using System.Diagnostics;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using NAudio.MediaFoundation;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;

var dryRun = args.Contains("--dry-run");
var force = args.Contains("--force");

if (!File.Exists("pubspec.yaml"))
{
    Console.Error.WriteLine("Run this from the project folder (the one with pubspec.yaml).");
    return 1;
}

const string cachePath = "tools/VoiceGen/cache.json";
var cache = File.Exists(cachePath)
    ? JsonSerializer.Deserialize<Dictionary<string, string>>(File.ReadAllText(cachePath)) ?? []
    : new Dictionary<string, string>();
int made = 0, skipped = 0;
var changedPacks = new List<string>();

try
{
    // 1. App prompts, bundled with the app. Plain text, so any engine can say them.
    {
        var cfg = JsonNode.Parse(File.ReadAllText("tools/VoiceGen/app_prompts.json"))!;
        var speaker = Speaker.From(cfg, dryRun);
        foreach (var (name, text) in cfg["prompts"]!.AsObject())
        {
            await Make($"assets/audio/voice/{name}.mp3", speaker, text!.GetValue<string>());
        }
    }

    // 2. Pack clips.
    foreach (var dir in Directory.GetDirectories("content").Order())
    {
        var voiceFile = Path.Combine(dir, "voice.json");
        var packFile = Path.Combine(dir, "pack.json");
        if (!File.Exists(voiceFile) || !File.Exists(packFile)) continue;

        var cfg = JsonNode.Parse(File.ReadAllText(voiceFile))!;
        var speaker = Speaker.From(cfg, dryRun);
        var clips = cfg[speaker.Engine]!["clips"]!.AsObject();
        var numberWords = cfg["numberWords"]?.AsArray().Select(w => w!.GetValue<string>()).ToArray() ?? [];
        var pack = JsonNode.Parse(File.ReadAllText(packFile))!;
        var before = pack.ToJsonString();
        var madeBefore = made;
        Console.WriteLine($"Pack {Path.GetFileName(dir)} ({speaker.Engine})");

        foreach (var item in pack["items"]!.AsArray())
        {
            var id = item!["id"]!.ToString();
            var audio = item["audio"]?.AsObject() ?? new JsonObject();
            foreach (var (clip, template) in clips)
            {
                var rel = $"audio/{id}_{clip}.mp3";
                var text = Fill(template!.GetValue<string>(), item.AsObject(), numberWords, speaker.EscapeXml);
                await Make(Path.Combine(dir, rel).Replace('\\', '/'), speaker, text);
                audio[clip] = rel;
            }
            if (item["audio"] is null) item.AsObject()["audio"] = audio;
        }

        if (!dryRun && pack.ToJsonString() != before)
        {
            var options = new JsonSerializerOptions
            {
                WriteIndented = true,
                Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping, // keep æ, ɪ, Hindi readable
            };
            File.WriteAllText(packFile, pack.ToJsonString(options).Replace("\r\n", "\n") + "\n");
        }
        if (made > madeBefore || pack.ToJsonString() != before) changedPacks.Add(Path.GetFileName(dir));
    }
}
catch (Exception e) when (e is InvalidDataException or FileNotFoundException or HttpRequestException)
{
    Console.Error.WriteLine($"\nStopped: {e.Message}");
    return 1;
}

Console.WriteLine($"\nMade {made} clip(s), {skipped} unchanged.");
if (!dryRun && changedPacks.Count > 0)
{
    Console.WriteLine($"Changed packs: {string.Join(", ", changedPacks)}.");
    Console.WriteLine("Next: raise \"version\" in their pack.json, then run: dart run tools/pack_builder.dart");
}
return 0;

async Task Make(string outPath, Speaker speaker, string text)
{
    var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(speaker.CacheKey(text))));
    if (!force && File.Exists(outPath) && cache.GetValueOrDefault(outPath) == hash)
    {
        skipped++;
        return;
    }
    if (dryRun)
    {
        Console.WriteLine($"  {outPath}\n    {text}");
        made++;
        return;
    }
    Directory.CreateDirectory(Path.GetDirectoryName(outPath)!);
    await File.WriteAllBytesAsync(outPath, await speaker.Speak(text));
    cache[outPath] = hash;
    File.WriteAllText(cachePath, JsonSerializer.Serialize(cache, new JsonSerializerOptions { WriteIndented = true }));
    Console.WriteLine($"  {outPath}");
    made++;
}

static string Fill(string template, JsonObject item, string[] numberWords, bool escapeXml)
{
    string? Value(string field)
    {
        if (field == "count")
        {
            var n = item["number"]?.GetValue<int>()
                ?? throw new InvalidDataException($"item {item["id"]}: {{count}} needs \"number\"");
            return string.Join(", ", numberWords.Take(n));
        }
        var v = item[field]?.ToString();
        return string.IsNullOrEmpty(v) ? null : escapeXml ? System.Security.SecurityElement.Escape(v) : v;
    }

    // Optional parts first: [ ... ] disappears when a field inside is empty.
    var text = Regex.Replace(template, @"\[([^\]]*)\]", m =>
        Regex.Matches(m.Groups[1].Value, @"\{(\w+)\}").Any(f => Value(f.Groups[1].Value) is null)
            ? ""
            : m.Groups[1].Value);
    text = Regex.Replace(text, @"\{(\w+)\}", m =>
        Value(m.Groups[1].Value) ?? throw new InvalidDataException($"item {item["id"]}: no field \"{m.Groups[1].Value}\""));
    return Regex.Replace(text, @"\s{2,}", " ").Trim();
}

/// Turns text into MP3 bytes with one engine.
abstract class Speaker
{
    public abstract string Engine { get; }
    public abstract bool EscapeXml { get; }
    public abstract string CacheKey(string text);
    public abstract Task<byte[]> Speak(string text);

    public static Speaker From(JsonNode cfg, bool dryRun)
    {
        var engine = cfg["engine"]?.GetValue<string>() ?? "piper";
        var settings = cfg[engine] ?? throw new InvalidDataException($"voice file has no \"{engine}\" settings");
        return engine switch
        {
            "piper" => new PiperSpeaker(settings, dryRun),
            "azure" => new AzureSpeaker(settings, dryRun),
            _ => throw new InvalidDataException($"unknown engine \"{engine}\""),
        };
    }

    /// WAV (any rate) to a small mono MP3, with Windows' own encoder.
    protected static byte[] ToMp3(byte[] wav)
    {
        MediaFoundationApi.Startup();
        using var reader = new WaveFileReader(new MemoryStream(wav));
        // The Windows MP3 encoder needs 44.1 or 48 kHz.
        var resampled = new WdlResamplingSampleProvider(reader.ToSampleProvider(), 44100);
        var tmp = Path.GetTempFileName() + ".mp3";
        try
        {
            MediaFoundationEncoder.EncodeToMp3(resampled.ToWaveProvider16(), tmp, 64000);
            return File.ReadAllBytes(tmp);
        }
        finally
        {
            File.Delete(tmp);
        }
    }
}

/// Piper: a free, offline neural voice. Plain text in, WAV out.
class PiperSpeaker : Speaker
{
    const string Exe = "tools/VoiceGen/piper/piper/piper.exe";
    readonly string _model;
    readonly double _lengthScale;
    readonly double _sentenceSilence;

    public PiperSpeaker(JsonNode s, bool dryRun)
    {
        _model = s["model"]!.GetValue<string>();
        _lengthScale = s["lengthScale"]?.GetValue<double>() ?? 1.0;
        _sentenceSilence = s["sentenceSilence"]?.GetValue<double>() ?? 0.3;
        if (!dryRun && (!File.Exists(Exe) || !File.Exists(_model)))
        {
            throw new FileNotFoundException($"Piper or its voice is missing ({Exe}, {_model}). See tools/VoiceGen/README.md.");
        }
    }

    public override string Engine => "piper";
    public override bool EscapeXml => false;
    public override string CacheKey(string text) => $"piper|{_model}|{_lengthScale}|{_sentenceSilence}|{text}";

    public override async Task<byte[]> Speak(string text)
    {
        var wav = Path.GetTempFileName() + ".wav";
        try
        {
            var psi = new ProcessStartInfo(Path.GetFullPath(Exe))
            {
                RedirectStandardInput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                StandardInputEncoding = new UTF8Encoding(false),
            };
            foreach (var a in new[] { "--model", _model, "--output_file", wav, "--length_scale",
                         $"{_lengthScale:0.00}", "--sentence_silence", $"{_sentenceSilence:0.00}", "--quiet" })
            {
                psi.ArgumentList.Add(a);
            }
            using var p = Process.Start(psi)!;
            await p.StandardInput.WriteLineAsync(text);
            p.StandardInput.Close();
            var err = await p.StandardError.ReadToEndAsync();
            await p.WaitForExitAsync();
            if (p.ExitCode != 0 || !File.Exists(wav)) throw new InvalidDataException($"Piper failed: {err}");
            return ToMp3(await File.ReadAllBytesAsync(wav));
        }
        finally
        {
            File.Delete(wav);
        }
    }
}

/// Azure Speech REST API, SSML in, MP3 out. The free tier allows 20
/// requests a minute, so requests are spaced out and retried when Azure
/// says "too many".
class AzureSpeaker : Speaker
{
    static readonly TimeSpan Gap = TimeSpan.FromSeconds(3.2);
    static readonly HttpClient Http = new();
    readonly string _voice, _lang, _rate, _key, _region;
    DateTime _last = DateTime.MinValue;

    public AzureSpeaker(JsonNode s, bool dryRun)
    {
        _voice = s["voice"]!.GetValue<string>();
        _lang = s["lang"]?.GetValue<string>() ?? "en-IN";
        _rate = s["rate"]?.GetValue<string>() ?? "0%";
        _key = Environment.GetEnvironmentVariable("AZURE_SPEECH_KEY") ?? "";
        _region = Environment.GetEnvironmentVariable("AZURE_SPEECH_REGION") ?? "centralindia";
        if (!dryRun && string.IsNullOrWhiteSpace(_key))
        {
            throw new InvalidDataException("AZURE_SPEECH_KEY is not set. See tools/VoiceGen/README.md.");
        }
    }

    public override string Engine => "azure";
    public override bool EscapeXml => true;
    public override string CacheKey(string text) => Ssml(text);

    string Ssml(string text) =>
        $"<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xml:lang=\"{_lang}\">" +
        $"<voice name=\"{_voice}\"><prosody rate=\"{_rate}\">{text}</prosody></voice></speak>";

    public override async Task<byte[]> Speak(string text)
    {
        var ssml = Ssml(text);
        for (var attempt = 1; ; attempt++)
        {
            var wait = _last + Gap - DateTime.UtcNow;
            if (wait > TimeSpan.Zero) await Task.Delay(wait);
            _last = DateTime.UtcNow;

            using var req = new HttpRequestMessage(HttpMethod.Post,
                $"https://{_region}.tts.speech.microsoft.com/cognitiveservices/v1")
            {
                Content = new StringContent(ssml, Encoding.UTF8, "application/ssml+xml"),
            };
            req.Headers.Add("Ocp-Apim-Subscription-Key", _key);
            req.Headers.Add("X-Microsoft-OutputFormat", "audio-24khz-48kbitrate-mono-mp3");
            req.Headers.Add("User-Agent", "KidsLearningApp-VoiceGen");

            using var res = await Http.SendAsync(req);
            if (res.IsSuccessStatusCode) return await res.Content.ReadAsByteArrayAsync();
            if (res.StatusCode == HttpStatusCode.TooManyRequests && attempt < 6)
            {
                await Task.Delay(res.Headers.RetryAfter?.Delta ?? TimeSpan.FromSeconds(15));
                continue;
            }
            var body = await res.Content.ReadAsStringAsync();
            throw new HttpRequestException($"Azure said {(int)res.StatusCode} {res.ReasonPhrase}. {body}\nSSML: {ssml}");
        }
    }
}
