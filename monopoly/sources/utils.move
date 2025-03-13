module monopoly::utils {
    public fun max_of_u8(values: vector<u8>): u8 {
        let mut res = 0;

        values.do!(|value| { if (value > res) res = value });

        res
    }
}
