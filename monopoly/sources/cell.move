module monopoly::cell {
    use monopoly::monopoly::{Game, ActionRequest};
    use std::string::String;

    // === Errors ===
    const ENotCell: u64 = 101;

    // === Constants ===

    // === Structs ===

    /// Empty body in argument
    public struct DoNothingArgument has copy, drop, store {}
    public struct Cell has key, store {
        id: UID,
        name: String,
    }

    // === Events ===

    // === Method Aliases ===

    // === Init Function ===

    // === Public Functions ===

    // === View Functions ===
    public fun name(self: &Cell,): String{ self.name }
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

    public fun drop_cell(self: Cell) {
        let Cell {
            id,
            name: _,
        } = self;

        object::delete(id);
    }

    public fun initialize_do_nothing_params(
        action_request: &mut ActionRequest<DoNothingArgument>,
        game: &Game,
    ) {
        // check if corresponding cell is normal Cell
        assert!(
            game.cell_contains_with_type<Cell>(action_request.action_request_pos_index()),
            ENotCell,
        );

        action_request.settle_action_request();
    }
}
