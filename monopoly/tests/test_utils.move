module monopoly::test_utils {
    use monopoly::house_cell::HouseCell;
    use std::string::String;
    use sui::vec_map::VecMap;

    public fun compare_vec_map<T1: copy, T2>(v1: &VecMap<T1, T2>, v2: &VecMap<T1, T2>) {
        let size = v1.size();
        assert!(size == v2.size());

        size.do!<()>(|idx| {
            let (v1_key, v1_value) = v1.get_entry_by_idx(idx);
            let (v2_key, v2_value) = v2.get_entry_by_idx(idx);

            assert!(v1_key == v2_key);
            assert!(v1_value == v2_value);
        });
    }

    // HouseCell
    public fun assert_house_cell_basic(
        house_cell: &HouseCell,
        owner: Option<address>,
        level: u8,
        name: String,
    ) {
        assert!(house_cell.owner() == owner);
        assert!(house_cell.level() == level);
        assert!(house_cell.name() == name);
    }

    public fun assert_house_cell_advanced(
        house_cell: &HouseCell,
        owner: Option<address>,
        level: u8,
        name: String,
        buy_prices: VecMap<u8, u64>,
        sell_prices: VecMap<u8, u64>,
        tolls: VecMap<u8, u64>,
    ) {
        assert_house_cell_basic(house_cell, owner, level, name);

        let (buy_prices_, sell_prices_, tolls_) = house_cell.house();
        compare_vec_map(&buy_prices_, &buy_prices);
        compare_vec_map(&sell_prices_, &sell_prices);
        compare_vec_map(&tolls_, &tolls);
    }
}
