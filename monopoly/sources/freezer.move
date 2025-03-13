module monopoly::freezer {
    public struct Ice<Asset: store> has key {
        id: UID,
        obj: Asset,
    }

    #[allow(lint(freeze_wrapped))]
    public entry fun freeze_object<Asset: store>(asset: Asset, ctx: &mut TxContext) {
        let ice = Ice<Asset> {
            id: object::new(ctx),
            obj: asset,
        };
        transfer::freeze_object<Ice<Asset>>(ice);
    }
}
