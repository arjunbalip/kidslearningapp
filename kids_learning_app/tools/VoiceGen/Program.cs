// VoiceGen: makes the app's spoken clips with Azure Neural TTS.
//
// Run from the project folder (the one with pubspec.yaml):
//   dotnet run --project tools/VoiceGen              make new or changed clips
//   dotnet run --project tools/VoiceGen -- --dry-run  show what would be said
//   dotnet run --project tools/VoiceGen -- --force    remake every clip
//
// Needs two environment variables (Azure portal > Speech service > Keys):
//   AZURE_SPEECH_KEY     one of the two keys
//   AZURE_SPEECH_REGION  e.g. centralindia (default)
//
// What it reads and writes:
//   tools/VoiceGen/app_prompts.json  -> assets/audio/voice/<name>.mp3
//   content/<pack>/voice.json        -> content/<pack>/audio/<item>_<clip>.mp3,
//                                       and the "audio" map of each item in pack.json
//
// Clip texts are SSML templates; {field} is filled from the pack item
// (XML-escaped), {count} counts up to the item's number ("One, two, three").
// Clips whose text did not change are skipped (tools/VoiceGen/cache.json),
// which keeps within Azure's free tier.

using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

var dryRun = args.Contains("--dry-run");
var force = args.Contains("--force");

if (!File.Exists("pubspec.yaml"))
{
    Console.Error.WriteLine("Run this from the project folder (the one with pubspec.yaml).");
    return 1;
}

var key = Environment.GetEnvironmentVariable("AZURE_SPEECH_KEY");
var region = Environment.GetEnvironmentVariable("AZURE_SPEECH_REGION") ?? "centralindia";
if (!dryRun && string.IsNullOrWhiteSpace(key))
{
    Console.Error.WriteLine("AZURE_SPEECH_KEY is not set. See tools/VoiceGen/README.md.");
    return 1;
}

const string cachePath = "tools/VoiceGen/cache.json";
var cache = File.Exists(cachePath)
    ? JsonSerializer.Deserialize<Dictionary<string, string>>(File.ReadAllText(cachePath)) ?? []
    : new Dictionary<string, string>();

var tts = new Tts(key ?? "", region);
int made = 0, skipped = 0;
var changedPacks = new List<string>();

// 1. App prompts, bundled with the app.
{
    var cfg = JsonNode.Parse(File.ReadAllText("tools/VoiceGen/app_prompts.json"))!;
    var voice = Voice.From(cfg);
    Directory.CreateDirectory("assets/audio/voice");
    foreach (var (name, text) in cfg["prompts"]!.AsObject())
    {
        await Make($"assets/audio/voice/{name}.mp3", voice.Ssml(text!.GetValue<string>()));
    }
}

// 2. Pack clips.
foreach (var dir in Directory.GetDirectories("content").Order())
{
    var voiceFile = Path.Combine(dir, "voice.json");
    var packFile = Path.Combine(dir, "pack.json");
    if (!File.Exists(voiceFile) || !File.Exists(packFile)) continue;

    var cfg = JsonNode.Parse(File.ReadAllText(voiceFile))!;
    var voice = Voice.From(cfg);
    var numberWords = cfg["numberWords"]?.AsArray().Select(w => w!.GetValue<string>()).ToArray() ?? [];
    var pack = JsonNode.Parse(File.ReadAllText(packFile))!;
    var before = pack.ToJsonString();
    var madeBefore = made;
    Console.WriteLine($"Pack {Path.GetFileName(dir)}");

    foreach (var item in pack["items"]!.AsArray())
    {
        var id = item!["id"]!.ToString();
        var audio = item["audio"]?.AsObject() ?? new JsonObject();
        foreach (var (clip, template) in cfg["clips"]!.AsObject())
        {
            var rel = $"audio/{id}_{clip}.mp3";
            var text = Fill(template!.GetValue<string>(), item.AsObject(), numberWords);
            await Make(Path.Combine(dir, rel).Replace('\\', '/'), voice.Ssml(text));
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

Console.WriteLine($"\nMade {made} clip(s), {skipped} unchanged.");
if (!dryRun && changedPacks.Count > 0)
{
    Console.WriteLine($"Changed packs: {string.Join(", ", changedPacks)}.");
    Console.WriteLine("Next: raise \"version\" in their pack.json, then run: dart run tools/pack_builder.dart");
}
return 0;

async Task Make(string outPath, string ssml)
{
    var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(ssml)));
    if (!force && File.Exists(outPath) && cache.GetValueOrDefault(outPath) == hash)
    {
        skipped++;
        return;
    }
    if (dryRun)
    {
        Console.WriteLine($"  {outPath}\n    {ssml}");
        made++;
        return;
    }
    Directory.CreateDirectory(Path.GetDirectoryName(outPath)!);
    await File.WriteAllBytesAsync(outPath, await tts.Speak(ssml));
    cache[outPath] = hash;
    File.WriteAllText(cachePath, JsonSerializer.Serialize(cache, new JsonSerializerOptions { WriteIndented = true }));
    Console.WriteLine($"  {outPath}");
    made++;
}

static string Fill(string template, JsonObject item, string[] numberWords) =>
    Regex.Replace(template, @"\{(\w+)\}", m =>
    {
        var field = m.Groups[1].Value;
        if (field == "count")
        {
            var n = item["number"]?.GetValue<int>() ?? throw new InvalidDataException($"item {item["id"]}: {{count}} needs \"number\"");
            return string.Join(", ", numberWords.Take(n));
        }
        var value = item[field] ?? throw new InvalidDataException($"item {item["id"]}: no field \"{field}\"");
        return System.Security.SecurityElement.Escape(value.ToString())!;
    });

record Voice(string Name, string Lang, string Rate)
{
    public static Voice From(JsonNode cfg) => new(
        cfg["voice"]!.GetValue<string>(),
        cfg["lang"]?.GetValue<string>() ?? "en-IN",
        cfg["rate"]?.GetValue<string>() ?? "0%");

    public string Ssml(string text) =>
        $"<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xml:lang=\"{Lang}\">" +
        $"<voice name=\"{Name}\"><prosody rate=\"{Rate}\">{text}</prosody></voice></speak>";
}

/// Azure Speech REST API. The free tier allows 20 requests a minute,
/// so requests are spaced out and retried when Azure says "too many".
class Tts(string key, string region)
{
    static readonly TimeSpan Gap = TimeSpan.FromSeconds(3.2);
    readonly HttpClient _http = new();
    DateTime _last = DateTime.MinValue;

    public async Task<byte[]> Speak(string ssml)
    {
        for (var attempt = 1; ; attempt++)
        {
            var wait = _last + Gap - DateTime.UtcNow;
            if (wait > TimeSpan.Zero) await Task.Delay(wait);
            _last = DateTime.UtcNow;

            using var req = new HttpRequestMessage(HttpMethod.Post,
                $"https://{region}.tts.speech.microsoft.com/cognitiveservices/v1")
            {
                Content = new StringContent(ssml, Encoding.UTF8, "application/ssml+xml"),
            };
            req.Headers.Add("Ocp-Apim-Subscription-Key", key);
            req.Headers.Add("X-Microsoft-OutputFormat", "audio-24khz-48kbitrate-mono-mp3");
            req.Headers.Add("User-Agent", "KidsLearningApp-VoiceGen");

            using var res = await _http.SendAsync(req);
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
