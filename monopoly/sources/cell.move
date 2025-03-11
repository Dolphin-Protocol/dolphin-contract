module monopoly::cell {
    use monopoly::monopoly::{Game, ActionRequest, AdminCap};
    use std::{option, string::String, type_name::{Self, TypeName}};
    use sui::{event, transfer::Receiving, vec_map::{Self, VecMap}, vec_set::{Self, VecSet}};

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
    public fun new_cell(ctx: &mut TxContext): Cell {
        Cell {
            id: object::new(ctx),
        }
    }
}

// === Package Functions ===

// === Private Functions ===
// === Test Functions ===
