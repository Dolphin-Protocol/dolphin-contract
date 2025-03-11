module monopoly::cell {
    use std::string::String;

    // === Errors ===

    // === Constants ===

    // === Structs ===

    public struct Cell has key, store {
        id: UID,
        name: String,
    }

    // === Events ===

    // === Method Aliases ===

    // === Init Function ===

    // === Public Functions ===

    // === View Functions ===

    // === Admin Functions ===

    // === Package Functions ===

    // === Private Functions ===

    // === Test Functions ===

    // create a new house cell
    public fun new_cell(name: String, ctx: &mut TxContext): Cell {
        Cell {
            id: object::new(ctx),
            name,
        }
    }
}
