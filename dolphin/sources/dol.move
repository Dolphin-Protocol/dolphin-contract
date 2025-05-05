/// Module: dolphin
module dolphin::DOL {
    use sui::{coin, url};

    public struct DOL has drop {}

    fun init(witness: DOL, ctx: &mut TxContext) {
        let (treasury, deny_cap, metadata) = coin::create_regulated_currency_v2(
            witness,
            9,
            b"DOL",
            b"DOL",
            b"",
            option::some(
                url::new_unsafe_from_bytes(
                    b"https://gateway.pinata.cloud/ipfs/bafkreifdfbyrrxvg6xpo44ljth3jkbban7ncbwfleyewgv5bdwxfvsflui",
                ),
            ),
            true,
            ctx,
        );

        transfer::public_share_object(metadata);
        transfer::public_transfer(treasury, ctx.sender());
        transfer::public_transfer(deny_cap, ctx.sender());
    }
}
