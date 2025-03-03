module monopoly::cell;
use std::string::String;

use monopoly::monopoly::{ Game, ActionRequest };

public struct House has store{
    name: String
}

public struct Cell has key, store{
    id: UID,
    house: Option<House>
}

// === Imports ===

// === Errors ===

// === Constants ===

// === Structs ===

// === Events ===

// === Method Aliases ===

// === Public Functions ===

// === View Functions ===

// === Admin Functions ===

// === Package Functions ===
public fun execute(
    game: &mut Game,
    request: &mut ActionRequest
){
    let cell = game.borrow_cell_mut_with_request<Cell>(request);

}

// === Private Functions ===

// === Test Functions ===
