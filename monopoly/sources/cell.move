module monopoly::cell;


public struct House has store{}

public struct Cell has key, store{
    id: UID,
    house: Option<House>
}
