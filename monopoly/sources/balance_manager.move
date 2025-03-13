module monopoly::balance_manager {
    use monopoly::freezer;
    use sui::{balance::{Self, Balance, Supply}, event, vec_map::{Self, VecMap}};

    const ENotExistPlayer: u64 = 101;

    public struct BalanceUpdateEvent<phantom T> has copy, drop {
        owner: address,
        value: u64,
    }

    public struct BalanceManager<phantom T> has key, store {
        id: UID,
        supply: Supply<T>,
        balances: VecMap<address, Balance<T>>,
    }

    public fun new<T>(supply: Supply<T>, ctx: &mut TxContext): BalanceManager<T> {
        BalanceManager {
            id: object::new(ctx),
            supply,
            balances: vec_map::empty(),
        }
    }

    public fun drop<T>(self: BalanceManager<T>, ctx: &mut TxContext): VecMap<address, u64> {
        let BalanceManager {
            id,
            mut supply,
            balances,
        } = self;

        object::delete(id);
        let (players, balances_) = balances.into_keys_values();

        let results = vec_map::from_keys_values(
            players,
            balances_.map!(|bal| supply.decrease_supply(bal)),
        );

        freezer::freeze_object(supply, ctx);

        results
    }

    public fun burn<T>(self: &mut BalanceManager<T>, balance: Balance<T>): u64 {
        self.supply.decrease_supply(balance)
    }

    /// @return; player's new balance value
    public fun add_balance<T>(self: &mut BalanceManager<T>, player: address, value: u64): u64 {
        if (!self.balances.contains(&player)) {
            self.balances.insert(player, balance::zero());
        };

        let new_balance = self.balances[&player].join(self.supply.increase_supply(value));

        event::emit(BalanceUpdateEvent<T> { owner: player, value: new_balance });

        new_balance
    }

    /// @return; deducted value
    public fun sub_balance<T>(self: &mut BalanceManager<T>, player: address, value: u64): u64 {
        if (!self.balances.contains(&player)) {
            self.balances.insert(player, balance::zero());
        };

        let deducted_value = self.supply.decrease_supply(self.balances[&player].split(value));

        event::emit(BalanceUpdateEvent<T> { owner: player, value: self.balances[&player].value() });

        deducted_value
    }

    /// @return; deducted value
    public fun saturating_sub_balance<T>(
        self: &mut BalanceManager<T>,
        player: address,
        value: u64,
    ): u64 {
        if (!self.balances.contains(&player)) {
            self.balances.insert(player, balance::zero());
        };

        let balance = &mut self.balances[&player];
        let removed_balance = if (balance.value() > value) {
            balance.split(value)
        } else {
            balance.withdraw_all()
        };

        event::emit(BalanceUpdateEvent<T> { owner: player, value: self.balances[&player].value() });

        self.supply.decrease_supply(removed_balance)
    }

    //@return; transferred amount
    public fun transfer<T>(
        self: &mut BalanceManager<T>,
        from: address,
        to: address,
        value: u64,
    ): u64 {
        let split_balance = self.balances[&from].split(value);

        event::emit(BalanceUpdateEvent<T> { owner: from, value: self.balances[&from].value() });
        event::emit(BalanceUpdateEvent<T> { owner: to, value: self.balances[&to].value() });

        self.balances[&to].join(split_balance)
    }

    public fun saturating_transfer<T>(
        self: &mut BalanceManager<T>,
        from: address,
        to: address,
        value_: u64,
    ): u64 {
        let from_balance = self.balances[&from].value();

        let value = if (from_balance >= value_) {
            value_
        } else {
            from_balance
        };
        let split_balance = self.balances[&from].split(value);
        let total = self.balances[&to].join(split_balance);

        event::emit(BalanceUpdateEvent<T> { owner: from, value: self.balances[&from].value() });
        event::emit(BalanceUpdateEvent<T> { owner: to, value: self.balances[&to].value() });

        total
    }

    // === Public View Functions ===
    public fun balance_of<T>(self: &BalanceManager<T>, player: address): &Balance<T> {
        // to bypass lifetime constraint, preventing using index method
        let mut idx_opt = self.balances.get_idx_opt(&player);

        assert!(idx_opt.is_some(), ENotExistPlayer);

        let (_, balance) = self.balances.get_entry_by_idx(idx_opt.extract());

        balance
    }

    public fun balance_of_mut<T>(self: &mut BalanceManager<T>, player: address): &mut Balance<T> {
        &mut self.balances[&player]
    }

    public fun supply<T>(self: &BalanceManager<T>): u64 {
        self.supply.supply_value()
    }
}
