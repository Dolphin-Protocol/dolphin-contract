#[test_only]
#[allow(unused)]
module monopoly::monopoly_tests {
    use monopoly::{
        cell::{Self, Cell},
        house_cell::{Self, HouseCell, BuyArgument},
        monopoly::{Self, AdminCap, Game, TurnCap, ActionRequest},
        test_utils
    };
    use std::{string::{Self, String}, type_name};
    use sui::{
        balance,
        clock::{Self, Clock},
        random::{Self, Random},
        test_scenario::{Self as test, Scenario, next_tx, ctx},
        vec_map::{Self, VecMap}
    };

    fun people(): (address, address, address, address, address) {
        (@0xA, @0xB, @0xC, @0xD, @0xE)
    }

    // Fabricated Balance Type
    public struct Monopoly has drop {}

    const START_TIME: u64 = 1000_000;

    // ref: https://www.falstad.com/monopoly.html
    const BUY_PRICE_INFOS: vector<vector<u64>> = vector[
        vector[10, 30, 90],
        vector[20, 60, 180],
        vector[30, 90, 270],
        vector[30, 90, 270],
        vector[40, 100, 300],
        vector[50, 150, 450],
        vector[50, 150, 450],
        vector[60, 180, 500],
        vector[70, 200, 550],
        vector[70, 200, 550],
        // 11th
        vector[80, 220, 600],
        vector[90, 250, 700],
        vector[90, 250, 700],
        vector[100, 300, 750],
        vector[110, 330, 800],
        vector[110, 330, 800],
        vector[120, 360, 850],
        vector[130, 390, 900],
        vector[130, 390, 900],
        vector[150, 450, 1000],
    ];

    const SELL_PRICE_INFOS: vector<vector<u64>> = vector[
        vector[5, 15, 45],
        vector[10, 30, 90],
        vector[15, 45, 135],
        vector[15, 45, 135],
        vector[20, 50, 150],
        vector[25, 75, 225],
        vector[25, 75, 225],
        vector[30, 90, 250],
        vector[35, 100, 275],
        vector[35, 100, 275],
        // 11th
        vector[40, 110, 300],
        vector[45, 125, 350],
        vector[45, 125, 350],
        vector[50, 150, 375],
        vector[55, 165, 400],
        vector[55, 165, 400],
        vector[60, 180, 425],
        vector[65, 195, 450],
        vector[65, 195, 450],
        vector[75, 225, 500],
    ];

    const TOLL_INFOS: vector<vector<u64>> = vector[
        vector[15, 45, 135],
        vector[30, 90, 270],
        vector[45, 135, 405],
        vector[45, 135, 405],
        vector[60, 150, 450],
        vector[75, 225, 675],
        vector[75, 225, 675],
        vector[90, 270, 750],
        vector[105, 300, 825],
        vector[105, 300, 825],
        // 11th
        vector[120, 330, 900],
        vector[135, 375, 1050],
        vector[135, 375, 1050],
        vector[150, 450, 1125],
        vector[165, 495, 1200],
        vector[165, 495, 1200],
        vector[180, 540, 1275],
        vector[195, 585, 1350],
        vector[195, 585, 1350],
        vector[225, 675, 1500],
    ];

    fun names(): vector<String> {
        vector[
            string::utf8(b"0"),
            string::utf8(b"1"),
            string::utf8(b"2"),
            string::utf8(b"3"),
            string::utf8(b"4"),
            string::utf8(b"5"),
            string::utf8(b"6"),
            string::utf8(b"7"),
            string::utf8(b"8"),
            string::utf8(b"9"),
            string::utf8(b"10"),
            string::utf8(b"11"),
            string::utf8(b"12"),
            string::utf8(b"13"),
            string::utf8(b"14"),
            string::utf8(b"15"),
            string::utf8(b"16"),
            string::utf8(b"17"),
            string::utf8(b"18"),
            string::utf8(b"19"),
        ]
    }

    fun prices_by_level(): (
        vector<VecMap<u8, u64>>,
        vector<VecMap<u8, u64>>,
        vector<VecMap<u8, u64>>,
    ) {
        let buy_price_infos = BUY_PRICE_INFOS;
        let sell_price_infos = SELL_PRICE_INFOS;
        let toll_infos = TOLL_INFOS;

        (buy_price_infos.map!(|buy_price_info| {
                let mut prices_by_levels = vec_map::empty<u8, u64>();

                buy_price_info.length().do!<()>(|idx| {
                    prices_by_levels.insert((idx as u8), buy_price_info[idx]);
                });

                prices_by_levels
            }), sell_price_infos.map!(|sell_price_info| {
                let mut prices_by_levels = vec_map::empty<u8, u64>();

                sell_price_info.length().do!<()>(|idx| {
                    prices_by_levels.insert((idx as u8), sell_price_info[idx]);
                });

                prices_by_levels
            }), toll_infos.map!(|toll_info| {
                let mut prices_by_levels = vec_map::empty<u8, u64>();

                toll_info.length().do!<()>(|idx| {
                    prices_by_levels.insert((idx as u8), toll_info[idx]);
                });

                prices_by_levels
            }))
    }

    fun setup(): (Scenario, Clock) {
        let (admin, b, c, d, e) = people();

        let mut scenario = test::begin(@0xA);
        let s = &mut scenario;
        let mut clock = clock::create_for_testing(ctx(s));

        let initial_fund = 2000;

        clock::set_for_testing(&mut clock, START_TIME);
        tx_context::increment_epoch_timestamp(ctx(s), START_TIME);
        monopoly::init_for_testing(ctx(s));
        house_cell::init_for_testing(ctx(s));

        s.next_tx(@0x0);
        {
            random::create_for_testing(ctx(s));
        };

        s.next_tx(admin);
        {
            let admin_cap = s.take_from_sender<AdminCap>();

            // order insetion determine plays order
            let players = vector[b, c, d, e];

            let mut game = admin_cap.new(players, ctx(s));

            // 1) cell setup
            // we will have 20 cells in 6x6 board game
            // setup game cells
            {
                // set up registry
                let names = names();
                let (buy_prices, sell_prices, tolls) = prices_by_level();
                let mut house_registry = s.take_shared<house_cell::HouseRegistry>();
                buy_prices.length().do!<u64>(|idx: u64| {
                    let buy_price = buy_prices[idx];
                    let sell_price = sell_prices[idx];
                    let toll = tolls[idx];

                    let (levels, buy_price_vec) = buy_price.into_keys_values();
                    let (_, sell_price_vec) = sell_price.into_keys_values();
                    let (_, toll_vec) = toll.into_keys_values();

                    house_registry.add_house_to_registry(
                        &admin_cap,
                        names[idx],
                        levels,
                        buy_price_vec,
                        sell_price_vec,
                        toll_vec,
                    );
                });

                20u64.do!<u64>(|idx: u64| {
                    // cells order
                    let name = *names.borrow(idx);
                    if (idx % 5 == 0) {
                        // cells at the corner are empty
                        let cell = cell::new_cell(name, ctx(s));
                        game.add_cell(&admin_cap, idx, cell);
                    } else {
                        let cell = house_cell::new_house_cell(
                            &house_registry,
                            name,
                            ctx(s),
                        );
                        game.add_cell(&admin_cap, idx, cell);
                    };
                });

                test::return_shared(house_registry);
            };

            // 2) Balance setup
            {
                let supply = balance::create_supply(Monopoly {});
                game.setup_balance<Monopoly>(&admin_cap, supply, initial_fund, ctx(s));
            };

            game.settle_game_creation(&admin_cap, admin, &clock, ctx(s));

            s.return_to_sender(admin_cap);
        };

        s.next_tx(admin);
        let game_id = {
            let game = s.take_from_sender<Game>();
            // check cells

            let num_of_cells = game.num_of_cells();
            assert!(num_of_cells == 20);

            num_of_cells.do!<()>(|pos_index| {
                if (pos_index % 5 == 0) {
                    assert!(game.cell_contains_with_type<Cell>(pos_index));
                } else {
                    assert!(game.cell_contains_with_type<HouseCell>(pos_index));
                    let house_cell = house_cell::borrow_house_cell_from_game(&game, pos_index);
                    test_utils::assert_house_cell_basic(
                        house_cell,
                        option::none(),
                        0,
                        pos_index.to_string(),
                    );
                };
            });

            // check balances
            game.players().do!(|player| {
                assert!(game.player_balance<Monopoly>(player).value() == initial_fund);
            });

            let game_id = object::id(&game);

            s.return_to_sender(game);

            game_id
        };

        // check first player recieve TurnCap
        s.next_tx(b);
        {
            let turn_cap = test::take_from_sender<TurnCap>(s);

            assert!(turn_cap.turn_cap_game() == game_id);
            assert!(turn_cap.turn_cap_player() == b);
            assert!(turn_cap.turn_cap_moved_steps() == 0);

            s.return_to_sender(turn_cap);
        };

        (scenario, clock)
    }

    #[test]
    fun test_monopoly_basic() {
        let (mut scenario, mut clock) = setup();
        let (admin, b, c, d, e) = people();
        let s = &mut scenario;

        // player B starts to play the gmae
        s.next_tx(b);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            // 1) roll the dice
            let moved_steps = turn_cap.player_move(&random, ctx(s));
            assert!(moved_steps == 9);

            test::return_shared(random);
        };

        // server resolve the moving action and emit ActionRequest
        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            // we've already known the moved_steps and corresponding action then, therefore we can config the PTB for requried generic parameters
            let mut action_request = game.request_player_move_for_testing<BuyArgument<Monopoly>>(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&game);
            game.request_player_action(action_request);
            let game_id = object::id(&game);

            s.return_to_sender(game);

            game_id
        };

        // player_b acquires ActionRequest and executee "buy_action" by required parameters
        s.next_tx(b);
        {
            let action_request = s.take_from_sender<ActionRequest<BuyArgument<Monopoly>>>();
            let (game_id_, player, new_pos_idx) = action_request.action_request_info();

            // check action_request info
            assert!(game_id == game_id_);
            assert!(player == b);
            assert!(new_pos_idx == 9);
            assert!(action_request.action_request_settled() == false);
            // checkw dynamic argument
            let buy_argument_opt = action_request.action_request_parameters<
                BuyArgument<Monopoly>,
            >();
            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (type_name, player_balance, house_price, purchased) = buy_argument.buy_argument_info();
            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 2000);
            assert!(house_price == 70);
            assert!(purchased == false);

            // settle action request then send the respone back to server
            let payment = 70;
            // action request has been sent to game object
            action_request.execute_buy_action(true);
        };

        s.next_tx(admin);
        {
            let mut game = s.take_from_sender<Game>();

            let action_request = s.take_from_address<ActionRequest<BuyArgument<Monopoly>>>(
                object::id_address(&game),
            );
            let buy_argument_opt = action_request.action_request_parameters();

            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (type_name, player_balance, house_price, purchased) = buy_argument.buy_argument_info();
            assert!(type_name == type_name::get<Monopoly>());
            assert!(player_balance == 2000);
            assert!(house_price == 70);
            assert!(purchased == true);
            // server settled buy action state
            house_cell::settle_buy_for_testing(action_request, &mut game, ctx(s));
            // check player balance, house, pos_index
            let player_balance = game.player_balance<Monopoly>(b).value();
            assert!(player_balance == 2000 - 70);
            assert!(game.player_position_of(b) == 9);

            let house_cell: &HouseCell = game.borrow_cell<HouseCell>(9);
            assert!(house_cell.house_cell_owner().extract() == b);
            assert!(house_cell.level() == 1);

            s.return_to_sender(game);
        };

        // player C starts next round
        s.next_tx(c);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            // 1) roll the dice
            let moved_steps = turn_cap.player_move(&random, ctx(s));
            // this is the chanceAction
            assert!(moved_steps == 4);

            test::return_shared(random);
        };

        scenario.end();
        clock.destroy_for_testing();
    }
}
