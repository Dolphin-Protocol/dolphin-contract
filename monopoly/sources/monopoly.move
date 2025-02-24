module monopoly::monopoly;

use monopoly::cell::Cell;


public struct Monopoly has key, store{
    id: UID,
    cells: vector<Cell>,
}

public struct DolphinOracle {}

