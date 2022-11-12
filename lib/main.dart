import 'dart:async';
import 'package:flutter/material.dart';
import 'Matrix.dart';
import 'tile.dart';

void main() {
  runApp(MaterialApp(
    title: '2048',
    theme: ThemeData(
      primarySwatch: Colors.blue,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    ),
    home: TwentyFortyEight(),
  ));
}

enum DirectionOfTheHandSwipeGesture { up, down, left, right }

class GameState {
  // this is the grid before the swipe has taken place
  final List<List<Tile>> _previousGrid;
  final DirectionOfTheHandSwipeGesture swipe;

  GameState(List<List<Tile>> previousGrid, this.swipe) : _previousGrid = previousGrid;


  List<List<Tile>> get previousGrid => _previousGrid.map(
          (row) => row.map(
                  (tile) => tile.copy()).toList()
  ).toList();
}

class TwentyFortyEight extends StatefulWidget {
  @override
  TwentyFortyEightState createState() => TwentyFortyEightState();
}

class TwentyFortyEightState extends State<TwentyFortyEight> with SingleTickerProviderStateMixin {
  AnimationController controller;

  List<List<Tile>> Matrix = List.generate(4, (y) => List.generate(4, (x) => Tile(x, y, 0)));
  List<GameState> StatesOfTheGame = [];
  List<Tile> AddTo = [];

  Iterable<Tile> get MatrixTiles => Matrix.expand(
          (e) => e
  );
  Iterable<Tile> get AllTheTiles => [MatrixTiles, AddTo].expand(
          (e) => e
  );
  List<List<Tile>> get ColorsForMatrix => List.generate(4,
          (x) => List.generate(
              4, (y) => Matrix[y][x])
  );

  Timer aiTimer;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(duration: Duration(milliseconds: 200), vsync: this);
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          AddTo.forEach((e) => Matrix[e.y][e.x].value = e.value);
          MatrixTiles.forEach((t) => t.resetAnimations());
          AddTo.clear();
        });
      }
    });

    NewGameCreator();
  }

  void NewGameCreator() {
    setState(() {
      StatesOfTheGame.clear();
      MatrixTiles.forEach((t) {
        t.value = 0;
        t.resetAnimations();
      });
      AddTo.clear();
      addNewTiles([2, 2]);
      controller.forward(from: 0);
    });
  }



  @override
  Widget build(BuildContext context) {
    double contentPadding = 16;
    double borderSize = 4;
    double gridSize = MediaQuery.of(context).size.width - contentPadding * 2;
    double tileSize = (gridSize - borderSize * 2) / 4;
    List<Widget> stackItems = [];
    stackItems.addAll(MatrixTiles.map((t) => TileWidget(
        x: tileSize * t.x,
        y: tileSize * t.y,
        containerSize: tileSize,
        size: tileSize - borderSize * 2,
        color: lightBrown)));
    stackItems.addAll(AllTheTiles.map((tile) => AnimatedBuilder(
        animation: controller,
        builder: (context, child) => tile.animatedValue.value == 0
            ? SizedBox()
            : TileWidget(
            x: tileSize * tile.animatedX.value,
            y: tileSize * tile.animatedY.value,
            containerSize: tileSize,
            size: (tileSize - borderSize * 2) * tile.size.value,
            color: numTileColor[tile.animatedValue.value],
            child: Center(child: TileNumber(tile.animatedValue.value))))));

    return Scaffold(
        backgroundColor: tan,
        body: Padding(
            padding: EdgeInsets.all(contentPadding),
            child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              Swiper(
                  up: () => {
                    MergingAllAvailableSetAfterASwipe(DirectionOfTheHandSwipeGesture.up),
                    print("up")
                  },
                  down: () => MergingAllAvailableSetAfterASwipe(DirectionOfTheHandSwipeGesture.down),
                  left: () => MergingAllAvailableSetAfterASwipe(DirectionOfTheHandSwipeGesture.left),
                  right: () => MergingAllAvailableSetAfterASwipe(DirectionOfTheHandSwipeGesture.right),
                  child: Container(
                      height: gridSize,
                      width: gridSize,
                      padding: EdgeInsets.all(borderSize),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(cornerRadius), color: darkBrown),
                      child: Stack(
                        children: stackItems,
                      ))),
              BigButton(label: "Undo", color: numColor, onPressed: StatesOfTheGame.isEmpty ? null : undoMove),
              BigButton(label: "Restart", color: orange, onPressed: NewGameCreator),
            ])));
  }

  void undoMove() {
    GameState previousState = StatesOfTheGame.removeLast();
    bool Function() mergeFn;
    switch (previousState.swipe) {
      case DirectionOfTheHandSwipeGesture.up:
        mergeFn = mergeUp;
        break;
      case DirectionOfTheHandSwipeGesture.down:
        mergeFn = mergeDown;
        break;
      case DirectionOfTheHandSwipeGesture.left:
        mergeFn = mergeLeft;
        break;
      case DirectionOfTheHandSwipeGesture.right:
        mergeFn = mergeRight;
        break;
    }
    setState(() {
      this.Matrix = previousState.previousGrid;
      mergeFn();
      controller.reverse(from: .99).then((_) {
        setState(() {
          this.Matrix = previousState.previousGrid;
          MatrixTiles.forEach((t) => t.resetAnimations());
        });
      });
    });
  }
  bool mergeLeft() => Matrix.map((e) => mergeTiles(e)).toList().any((e) => e);
  bool mergeRight() => Matrix.map((e) => mergeTiles(e.reversed.toList())).toList().any((e) => e);
  bool mergeUp() => ColorsForMatrix.map((e) => mergeTiles(e)).toList().any((e) => e);
  bool mergeDown() => ColorsForMatrix.map((e) => mergeTiles(e.reversed.toList())).toList().any((e) => e);


  void MergingAllAvailableSetAfterASwipe(DirectionOfTheHandSwipeGesture direction) {
    bool Function() mergeFn;
    switch (direction) {
      case DirectionOfTheHandSwipeGesture.up:
        mergeFn = mergeUp;
        break;
      case DirectionOfTheHandSwipeGesture.left:
        mergeFn = mergeLeft;
        break;
      case DirectionOfTheHandSwipeGesture.right:
        mergeFn = mergeRight;
        break;
      case DirectionOfTheHandSwipeGesture.down:
        mergeFn = mergeDown;
        break;
    }
    List<List<Tile>> gridBeforeSwipe = Matrix.map((row) => row.map((tile) => tile.copy()).toList()).toList();
    setState(() {
      if (mergeFn()) {
        StatesOfTheGame.add(GameState(gridBeforeSwipe, direction));
        addNewTiles([2]);
        controller.forward(from: 0);
      }
    });
  }



  bool mergeTiles(List<Tile> tiles) {
    bool didChange = false;
    for (int i = 0; i < tiles.length; i++) {
      for (int j = i; j < tiles.length; j++) {
        if (tiles[j].value != 0) {
          Tile mergeTile = tiles.skip(j + 1).firstWhere((t) => t.value != 0, orElse: () => null);
          if (mergeTile != null && mergeTile.value != tiles[j].value) {
            mergeTile = null;
          }
          if (i != j || mergeTile != null) {
            didChange = true;
            int resultValue = tiles[j].value;
            tiles[j].moveTo(controller, tiles[i].x, tiles[i].y);
            if (mergeTile != null) {
              resultValue += mergeTile.value;
              mergeTile.moveTo(controller, tiles[i].x, tiles[i].y);
              mergeTile.bounce(controller);
              mergeTile.changeNumber(controller, resultValue);
              mergeTile.value = 0;
              tiles[j].changeNumber(controller, 0);
            }
            tiles[j].value = 0;
            tiles[i].value = resultValue;
          }
          break;
        }
      }
    }
    return didChange;
  }

  void addNewTiles(List<int> values) {
    List<Tile> empty = MatrixTiles.where((t) => t.value == 0).toList();
    empty.shuffle();
    for (int i = 0; i < values.length; i++) {
      AddTo.add(Tile(empty[i].x, empty[i].y, values[i])..appear(controller));
    }
  }

}
