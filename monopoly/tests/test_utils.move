module monopoly::test_utils {
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
}
