module monopoly::cell;
// === Imports ===
use std::string::String;
use std::type_name::{ Self, TypeName };
use std::option::{Self};

use sui::event;
use sui::vec_map::{ Self, VecMap };
use sui::vec_set::{Self, VecSet};
use sui::transfer::Receiving;
use monopoly::monopoly::{ Game, ActionRequest, AdminCap };

// === Errors ===
// === Constants ===
const VERSION: u64 = 1;
// === Structs ===
public struct Cell has key, store {
    id: UID,
}

// === Events ===

// === Method Aliases === 

// === Init Function ===

// === Public Functions ===

// === View Functions ===

// === Admin Functions ===

// create a new house cell
public fun new_cell(
    ctx: &mut TxContext
):Cell{
    Cell {
        id: object::new(ctx),
    }
}

// === Package Functions ===

// === Private Functions ===
// === Test Functions ===
