module monopoly::supply {
    use monopoly::monopoly::AdminCap;
    use sui::balance::{Self, Supply};

    public struct Monopoly has drop {}

    public struct StoredSupply<phantom T> has key {
        id: UID,
        supply: Supply<T>,
    }

    public fun new_supply(_cap: &AdminCap): Supply<Monopoly> {
        balance::create_supply(Monopoly {})
    }

    public fun burn_supply(_cap: &AdminCap): Supply<Monopoly> {
        balance::create_supply(Monopoly {})
    }

    public fun store_supply<T>(supply: Supply<T>, to: address, ctx: &mut TxContext) {
        let dolphin_supply = StoredSupply<T> { id: object::new(ctx), supply };

        transfer::transfer(dolphin_supply, to);
    }

    public fun take_supply<T>(self: StoredSupply<T>): Supply<T> {
        let StoredSupply<T> { id, supply } = self;

        object::delete(id);

        supply
    }
}
