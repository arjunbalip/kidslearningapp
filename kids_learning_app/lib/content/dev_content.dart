/// Built-in development content.
///
/// This stands in for the downloadable Letters and Numbers packs until the
/// pack system (milestone 2) is ready. Words and objects follow the
/// Content Plan.
library;

const _img = 'assets/dev_content';

class LetterItem {
  const LetterItem(this.upper, this.lower, this.word, this.image);

  final String upper;
  final String lower;
  final String word;

  /// Picture for the word; null until a picture exists (X, Xylophone).
  final String? image;
}

class NumberItem {
  const NumberItem(this.value, this.word, this.label, this.image);

  final int value;
  final String word; // "Three"
  final String label; // "Three balls!"
  final String image; // one object, shown [value] times
}

const List<LetterItem> devLetters = [
  LetterItem('A', 'a', 'Apple', '$_img/apple.png'),
  LetterItem('B', 'b', 'Ball', '$_img/ball.png'),
  LetterItem('C', 'c', 'Cat', '$_img/cat.png'),
  LetterItem('D', 'd', 'Dog', '$_img/dog.png'),
  LetterItem('E', 'e', 'Elephant', '$_img/elephant.png'),
  LetterItem('F', 'f', 'Fish', '$_img/fish.png'),
  LetterItem('G', 'g', 'Grapes', '$_img/grapes.png'),
  LetterItem('H', 'h', 'House', '$_img/house.png'),
  LetterItem('I', 'i', 'Ice cream', '$_img/ice_cream.png'),
  LetterItem('J', 'j', 'Jar', '$_img/jar.png'),
  LetterItem('K', 'k', 'Kite', '$_img/kite.png'),
  LetterItem('L', 'l', 'Lion', '$_img/lion.png'),
  LetterItem('M', 'm', 'Monkey', '$_img/monkey.png'),
  LetterItem('N', 'n', 'Nest', '$_img/nest.png'),
  LetterItem('O', 'o', 'Orange', '$_img/orange.png'),
  LetterItem('P', 'p', 'Parrot', '$_img/parrot.png'),
  LetterItem('Q', 'q', 'Queen', '$_img/queen.png'),
  LetterItem('R', 'r', 'Rabbit', '$_img/rabbit.png'),
  LetterItem('S', 's', 'Sun', '$_img/sun.png'),
  LetterItem('T', 't', 'Tiger', '$_img/tiger.png'),
  LetterItem('U', 'u', 'Umbrella', '$_img/umbrella.png'),
  LetterItem('V', 'v', 'Violin', '$_img/violin.png'),
  LetterItem('W', 'w', 'Watch', '$_img/watch.png'),
  LetterItem('X', 'x', 'Xylophone', null),
  LetterItem('Y', 'y', 'Yo-yo', '$_img/yoyo.png'),
  LetterItem('Z', 'z', 'Zebra', '$_img/zebra.png'),
];

const List<NumberItem> devNumbers = [
  NumberItem(1, 'One', 'One moon!', '$_img/moon.png'),
  NumberItem(2, 'Two', 'Two ducks!', '$_img/duck.png'),
  NumberItem(3, 'Three', 'Three balls!', '$_img/ball.png'),
  NumberItem(4, 'Four', 'Four fish!', '$_img/fish.png'),
  NumberItem(5, 'Five', 'Five stars!', '$_img/star.png'),
  NumberItem(6, 'Six', 'Six strawberries!', '$_img/strawberry.png'),
  NumberItem(7, 'Seven', 'Seven butterflies!', '$_img/butterfly.png'),
  NumberItem(8, 'Eight', 'Eight ladybugs!', '$_img/ladybug.png'),
  NumberItem(9, 'Nine', 'Nine balloons!', '$_img/balloon.png'),
  NumberItem(10, 'Ten', 'Ten flowers!', '$_img/flower.png'),
];
