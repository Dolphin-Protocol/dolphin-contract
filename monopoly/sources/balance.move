module monopoly::balance {
    /// For when trying to destroy a non-zero balance.
    const ENonZero: u64 = 0;
    /// For when an overflow is happening on Supply operations.
    const EOverflow: u64 = 1;
    /// For when trying to withdraw more than there is.
    const ENotEnough: u64 = 2;
    const ECirculatingSupply: u64 = 3;

    /// A Supply of T. Used for minting and burning.
    /// Wrapped into a `TreasuryCap` in the `Coin` module.
    public struct Supply<phantom T> has store {
        value: u64,
    }

    /// Storable balance - an inner struct of a Coin type.
    /// Can be used to store coins which don't need the key ability.
    public struct Balance<phantom T> has store {
        value: u64,
    }

    /// Get the amount stored in a `Balance`.
    public fun value<T>(self: &Balance<T>): u64 {
        self.value
    }

    /// Get the `Supply` value.
    public fun supply_value<T>(supply: &Supply<T>): u64 {
        supply.value
    }

    /// Create a new supply for type T.
    public fun create_supply<T: drop>(_: T): Supply<T> {
        Supply { value: 0 }
    }

    /// Destroy new supply for type T.
    public fun destroy_supply<T: drop>(supply: Supply<T>) {
        assert!(supply.value == 0, ECirculatingSupply);
        let Supply { value: _ } = supply;
    }

    /// Increase supply by `value` and create a new `Balance<T>` with this value.
    public fun increase_supply<T>(self: &mut Supply<T>, value: u64): Balance<T> {
        assert!(value < (18446744073709551615u64 - self.value), EOverflow);
        self.value = self.value + value;
        Balance { value }
    }

    /// Burn a Balance<T> and decrease Supply<T>.
    public fun decrease_supply<T>(self: &mut Supply<T>, balance: Balance<T>): u64 {
        let Balance { value } = balance;
        assert!(self.value >= value, EOverflow);
        self.value = self.value - value;
        value
    }

    /// Create a zero `Balance` for type `T`.
    public fun zero<T>(): Balance<T> {
        Balance { value: 0 }
    }

    /// Join two balances together.
    public fun join<T>(self: &mut Balance<T>, balance: Balance<T>): u64 {
        let Balance { value } = balance;
        self.value = self.value + value;
        self.value
    }

    /// Split a `Balance` and take a sub balance from it.
    public fun split<T>(self: &mut Balance<T>, value: u64): Balance<T> {
        assert!(self.value >= value, ENotEnough);
        self.value = self.value - value;
        Balance { value }
    }

    /// Withdraw all balance. After this the remaining balance must be 0.
    public fun withdraw_all<T>(self: &mut Balance<T>): Balance<T> {
        let value = self.value;
        split(self, value)
    }

    /// Destroy a zero `Balance`.
    public fun destroy_zero<T>(balance: Balance<T>) {
        assert!(balance.value == 0, ENonZero);
        let Balance { value: _ } = balance;
    }

    #[test_only]
    /// Create a `Balance` of any coin for testing purposes.
    public fun create_for_testing<T>(value: u64): Balance<T> {
        Balance { value }
    }

    #[test_only]
    /// Destroy a `Balance` of any coin for testing purposes.
    public fun destroy_for_testing<T>(self: Balance<T>): u64 {
        let Balance { value } = self;
        value
    }

    #[test_only]
    /// Create a `Supply` of any coin for testing purposes.
    public fun create_supply_for_testing<T>(): Supply<T> {
        Supply { value: 0 }
    }
}
