#[test_only]
#[allow(unused)]
module monopoly::monopoly_basic_tests {
    use monopoly::{
        balance,
        cell::{Self, Cell, DoNothingArgument},
        house_cell::{Self, HouseCell, BuyArgument},
        monopoly::{Self, AdminCap, Game, TurnCap, ActionRequest, Monopoly},
        test_utils
    };
    use std::{string::{Self, String}, type_name};
    use sui::{
        clock::{Self, Clock},
        random::{Self, Random},
        test_scenario::{Self as test, Scenario, next_tx, ctx},
        vec_map::{Self, VecMap}
    };

    fun people(): (address, address, address, address, address) {
        (@0xA, @0xB, @0xC, @0xD, @0xE)
    }

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
                    prices_by_levels.insert((idx + 1 as u8), buy_price_info[idx]);
                });

                prices_by_levels
            }), sell_price_infos.map!(|sell_price_info| {
                let mut prices_by_levels = vec_map::empty<u8, u64>();

                sell_price_info.length().do!<()>(|idx| {
                    prices_by_levels.insert((idx + 1as u8), sell_price_info[idx]);
                });

                prices_by_levels
            }), toll_infos.map!(|toll_info| {
                let mut prices_by_levels = vec_map::empty<u8, u64>();

                toll_info.length().do!<()>(|idx| {
                    prices_by_levels.insert((idx + 1 as u8), toll_info[idx]);
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
            let max_rounds = 5;
            let max_steps = 12;
            let salary = 100;

            let mut game = admin_cap.new(players, max_rounds, max_steps, 100, initial_fund, ctx(s));

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

            game.settle_game_creation(&admin_cap, admin, ctx(s));

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
                assert!(game.player_balance(player).value() == initial_fund);
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

    fun breakpoint_1(): (Scenario, Clock) {
        let (mut scenario, mut clock) = setup();
        let (admin, b, c, d, e) = people();
        let s = &mut scenario;

        // === player B turn ===

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
            let mut action_request = game.request_player_move_for_testing<BuyArgument>(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.request_player_action(action_request);
            let game_id = object::id(&game);

            s.return_to_sender(game);

            game_id
        };

        // player_b acquires ActionRequest and executee "buy_action" by required parameters
        s.next_tx(b);
        {
            let action_request = s.take_from_sender<ActionRequest<BuyArgument>>();
            let (game_id_, player, new_pos_idx) = action_request.action_request_info();

            // check action_request info
            assert!(game_id == game_id_);
            assert!(player == b);
            assert!(new_pos_idx == 9);
            assert!(action_request.action_request_settled() == false);
            // checkw dynamic argument
            let buy_argument_opt = action_request.action_request_parameters<BuyArgument>();
            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (player_balance, house_price, level, purchased) = buy_argument.buy_argument_info();
            assert!(player_balance == 2000);
            assert!(house_price == 70);
            assert!(level == 0);
            assert!(purchased == false);

            // settle action request then send the respone back to server
            let payment = 70;
            // action request has been sent to game object
            action_request.execute_buy_action(true, ctx(s));
        };

        s.next_tx(admin);
        {
            let mut game = s.take_from_sender<Game>();

            let action_request = s.take_from_address<ActionRequest<BuyArgument>>(
                object::id_address(&game),
            );
            let buy_argument_opt = action_request.action_request_parameters();

            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (player_balance, house_price, level, purchased) = buy_argument.buy_argument_info();
            assert!(player_balance == 2000);
            assert!(house_price == 70);
            assert!(level == 0);
            assert!(purchased == true);
            // server settled buy action state
            house_cell::settle_buy_for_testing(action_request, &mut game, ctx(s));
            // check player balance, house, pos_index
            let player_balance = game.player_balance(b).value();
            assert!(player_balance == 2000 - 70);
            assert!(game.player_position_of(b) == 9);

            let house_cell: &HouseCell = game.borrow_cell<HouseCell>(9);
            assert!(house_cell.house_cell_owner().extract() == b);
            assert!(house_cell.level() == 1);

            assert!(game.current_round() == 0);
            assert!(game.plays() == 1);

            s.return_to_sender(game);
        };

        // === player C turn ===

        // player C starts next round
        s.next_tx(c);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            // 1) roll the dice
            let moved_steps = turn_cap.player_move(&random, ctx(s));
            assert!(moved_steps == 4);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            let mut action_request = game.request_player_move_for_testing<BuyArgument>(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.request_player_action(action_request);
            let game_id = object::id(&game);

            s.return_to_sender(game);

            game_id
        };

        s.next_tx(c);
        {
            let action_request = s.take_from_sender<ActionRequest<BuyArgument>>();
            let (game_id_, player, new_pos_idx) = action_request.action_request_info();

            // check action_request info
            assert!(game_id == game_id_);
            assert!(player == c);
            assert!(new_pos_idx == 4);
            assert!(action_request.action_request_settled() == false);
            // checkw dynamic argument
            let buy_argument_opt = action_request.action_request_parameters<BuyArgument>();
            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (player_balance, house_price, level, purchased) = buy_argument.buy_argument_info();
            assert!(player_balance == 2000);
            assert!(house_price == 40);
            assert!(level == 0);
            assert!(purchased == false);

            // player_c refuse to buy
            action_request.execute_buy_action(false, ctx(s));
        };

        s.next_tx(admin);
        {
            let mut game = s.take_from_sender<Game>();

            let action_request = s.take_from_address<ActionRequest<BuyArgument>>(
                object::id_address(&game),
            );
            let buy_argument_opt = action_request.action_request_parameters();

            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (player_balance, house_price, level, purchased) = buy_argument.buy_argument_info();
            assert!(player_balance == 2000);
            assert!(house_price == 40);
            assert!(level == 0);
            assert!(purchased == false);
            // server settled buy action state
            house_cell::settle_buy_for_testing(action_request, &mut game, ctx(s));

            // game state

            // check player balance, house, pos_index
            let player_balance = game.player_balance(c).value();
            // player balance unchanged
            assert!(player_balance == 2000 - 0);
            assert!(game.player_position_of(c) == 4);

            let house_cell: &HouseCell = game.borrow_cell<HouseCell>(4);
            // house_info remains
            assert!(house_cell.house_cell_owner().is_none());
            assert!(house_cell.level() == 0);

            assert!(game.current_round() == 0);
            assert!(game.plays() == 2);

            s.return_to_sender(game);
        };

        // === player D turn ===

        s.next_tx(d);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            // 1) roll the dice
            let moved_steps = turn_cap.player_move(&random, ctx(s));
            assert!(moved_steps == 10);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            // we've already known the moved_steps and corresponding action then, therefore we can config the PTB for requried generic parameters
            let mut action_request = game.request_player_move_for_testing<DoNothingArgument>(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_do_nothing_params(&game);
            game.drop_action_request(action_request, ctx(s));

            assert!(game.player_position_of(d) == 10);
            assert!(game.current_round() == 0);
            assert!(game.plays() == 3);
            assert!(game.player_balance(d).value() == 2000);

            s.return_to_sender(game);

            game_id
        };

        // === player E turn ===

        s.next_tx(e);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            // 1) roll the dice
            let moved_steps = turn_cap.player_move(&random, ctx(s));
            assert!(moved_steps == 3);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            let mut action_request = game.request_player_move_for_testing<BuyArgument>(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.request_player_action(action_request);
            let game_id = object::id(&game);

            s.return_to_sender(game);

            game_id
        };

        s.next_tx(e);
        {
            let action_request = s.take_from_sender<ActionRequest<BuyArgument>>();
            let (game_id_, player, new_pos_idx) = action_request.action_request_info();

            // check action_request info
            assert!(game_id == game_id_);
            assert!(player == e);
            assert!(new_pos_idx == 3);
            assert!(action_request.action_request_settled() == false);
            // checkw dynamic argument
            let buy_argument_opt = action_request.action_request_parameters<BuyArgument>();
            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (player_balance, house_price, level, purchased) = buy_argument.buy_argument_info();
            assert!(player_balance == 2000);
            assert!(house_price == 30);
            assert!(level == 0);
            assert!(purchased == false);

            // player_c refuse to buy
            action_request.execute_buy_action(true, ctx(s));
        };

        s.next_tx(admin);
        {
            let mut game = s.take_from_sender<Game>();

            let action_request = s.take_from_address<ActionRequest<BuyArgument>>(
                object::id_address(&game),
            );
            let buy_argument_opt = action_request.action_request_parameters();

            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (player_balance, house_price, level, purchased) = buy_argument.buy_argument_info();
            assert!(player_balance == 2000);
            assert!(house_price == 30);
            assert!(level == 0);
            assert!(purchased == true);
            // server settled buy action state
            house_cell::settle_buy_for_testing(action_request, &mut game, ctx(s));
            // check player balance, house, pos_index
            let player_balance = game.player_balance(e).value();
            assert!(player_balance == 2000 - 30);
            assert!(game.player_position_of(e) == 3);

            let house_cell: &HouseCell = game.borrow_cell<HouseCell>(3);
            assert!(house_cell.house_cell_owner().extract() == e);
            assert!(house_cell.level() == 1);

            assert!(game.current_round() == 1);
            assert!(game.plays() == 4);

            s.return_to_sender(game);
        };

        // === player B turn ===

        s.next_tx(b);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            // 1) roll the dice
            let moved_steps = turn_cap.player_move(&random, ctx(s));
            assert!(moved_steps == 1);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            let mut action_request = game.request_player_move_for_testing<DoNothingArgument>(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_do_nothing_params(&game);
            game.drop_action_request(action_request, ctx(s));

            assert!(game.player_position_of(d) == 10);
            assert!(game.current_round() == 1);
            assert!(game.plays() == 5);
            assert!(game.player_balance(b).value() == 1930);

            s.return_to_sender(game);

            game_id
        };

        // === player C turn ===

        s.next_tx(c);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            // 1) roll the dice
            let moved_steps = turn_cap.player_move(&random, ctx(s));
            assert!(moved_steps == 7);

            test::return_shared(random);
        };
        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            let mut action_request = game.request_player_move_for_testing<BuyArgument>(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.request_player_action(action_request);
            let game_id = object::id(&game);

            s.return_to_sender(game);

            game_id
        };

        s.next_tx(c);
        {
            let action_request = s.take_from_sender<ActionRequest<BuyArgument>>();
            let (game_id_, player, new_pos_idx) = action_request.action_request_info();

            // check action_request info
            assert!(game_id == game_id_);
            assert!(player == c);
            assert!(new_pos_idx == 11);
            assert!(action_request.action_request_settled() == false);
            // checkw dynamic argument
            let buy_argument_opt = action_request.action_request_parameters<BuyArgument>();
            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (player_balance, house_price, level, purchased) = buy_argument.buy_argument_info();
            assert!(player_balance == 2000);
            assert!(house_price == 90);
            assert!(level == 0);
            assert!(purchased == false);

            // player_c refuse to buy
            action_request.execute_buy_action(true, ctx(s));
        };

        s.next_tx(admin);
        {
            let mut game = s.take_from_sender<Game>();

            let action_request = s.take_from_address<ActionRequest<BuyArgument>>(
                object::id_address(&game),
            );
            let buy_argument_opt = action_request.action_request_parameters();

            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (player_balance, house_price, level, purchased) = buy_argument.buy_argument_info();
            assert!(player_balance == 2000);
            assert!(house_price == 90);
            assert!(level == 0);
            assert!(purchased == true);
            // server settled buy action state
            house_cell::settle_buy_for_testing(action_request, &mut game, ctx(s));

            // game state

            // check player balance, house, pos_index
            let player_balance = game.player_balance(c).value();
            // player balance unchanged
            assert!(player_balance == 2000 - 90);
            assert!(game.player_position_of(c) == 11);

            let house_cell: &HouseCell = game.borrow_cell<HouseCell>(11);
            // house_info remains
            assert!(house_cell.house_cell_owner().borrow() == c);
            assert!(house_cell.level() == 1);

            assert!(game.current_round() == 1);
            assert!(game.plays() == 6);

            s.return_to_sender(game);
        };

        // === player D turn ===

        s.next_tx(d);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            // 1) roll the dice
            let moved_steps = turn_cap.player_move(&random, ctx(s));
            assert!(moved_steps == 10);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            let mut action_request = game.request_player_move_for_testing<DoNothingArgument>(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_do_nothing_params(&game);
            game.drop_action_request(action_request, ctx(s));

            assert!(game.player_position_of(d) == 0);
            assert!(game.current_round() == 1);
            assert!(game.plays() == 7);
            // player_d back to start point, should not recieve salary
            assert!(game.player_balance(d).value() == 2000);

            s.return_to_sender(game);

            game_id
        };

        // === player E turn ===

        s.next_tx(e);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move(&random, ctx(s));
            assert!(moved_steps == 3);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            let mut action_request = game.request_player_move_for_testing<BuyArgument>(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.request_player_action(action_request);
            let game_id = object::id(&game);

            s.return_to_sender(game);

            game_id
        };

        s.next_tx(e);
        {
            let action_request = s.take_from_sender<ActionRequest<BuyArgument>>();
            let (game_id_, player, new_pos_idx) = action_request.action_request_info();

            // check action_request info
            assert!(game_id == game_id_);
            assert!(player == e);
            assert!(new_pos_idx == 6);
            assert!(action_request.action_request_settled() == false);
            // checkw dynamic argument
            let buy_argument_opt = action_request.action_request_parameters<BuyArgument>();
            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (player_balance, house_price, level, purchased) = buy_argument.buy_argument_info();
            assert!(player_balance == 2000 - 30);
            assert!(house_price == 50);
            assert!(level == 0);
            assert!(purchased == false);

            action_request.execute_buy_action(true, ctx(s));
        };

        s.next_tx(admin);
        {
            let mut game = s.take_from_sender<Game>();

            let action_request = s.take_from_address<ActionRequest<BuyArgument>>(
                object::id_address(&game),
            );
            let buy_argument_opt = action_request.action_request_parameters();

            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (player_balance, house_price, level, purchased) = buy_argument.buy_argument_info();
            assert!(player_balance == 1970);
            assert!(house_price == 50);
            assert!(level == 0);
            assert!(purchased == true);
            // server settled buy action state
            house_cell::settle_buy_for_testing(action_request, &mut game, ctx(s));
            // check player balance, house, pos_index
            let player_balance = game.player_balance(e).value();
            assert!(player_balance == 2000 - 30 - 50);
            assert!(game.player_position_of(e) == 6);

            let house_cell: &HouseCell = game.borrow_cell<HouseCell>(6);
            assert!(house_cell.house_cell_owner().extract() == e);
            assert!(house_cell.level() == 1);

            assert!(game.current_round() == 2);
            assert!(game.plays() == 8);

            s.return_to_sender(game);
        };

        // === player B turn ===

        s.next_tx(b);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move_for_testing(1);
            assert!(moved_steps == 1);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            // player_b pay "375" toll to player_c
            let mut action_request = game.request_player_move_for_testing<BuyArgument>(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.drop_action_request(action_request, ctx(s));

            assert!(game.player_position_of(b) == 11);
            assert!(game.current_round() == 2);
            assert!(game.plays() == 9);

            // player_balance;
            assert!(game.player_balance(b).value() == 1930 - 135);
            assert!(game.player_balance(c).value() == 1910 + 135);

            s.return_to_sender(game);

            game_id
        };

        // === player C turn ===

        s.next_tx(c);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move_for_testing(11);
            assert!(moved_steps == 11);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            let mut action_request = game.request_player_move_for_testing<BuyArgument>(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.request_player_action(action_request);
            let game_id = object::id(&game);

            // recieve salary
            assert!(game.player_balance(c).value() == 2045 + 100);

            s.return_to_sender(game);

            game_id
        };

        s.next_tx(c);
        {
            let action_request = s.take_from_sender<ActionRequest<BuyArgument>>();
            let (game_id_, player, new_pos_idx) = action_request.action_request_info();

            // check action_request info
            assert!(game_id == game_id_);
            assert!(player == c);
            assert!(new_pos_idx == 2);
            assert!(action_request.action_request_settled() == false);
            // checkw dynamic argument
            let buy_argument_opt = action_request.action_request_parameters<BuyArgument>();
            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (player_balance, house_price, level, purchased) = buy_argument.buy_argument_info();
            assert!(player_balance == 2045 + 100);
            assert!(house_price == 30);
            assert!(level == 0);
            assert!(purchased == false);

            action_request.execute_buy_action(true, ctx(s));
        };

        s.next_tx(admin);
        {
            let mut game = s.take_from_sender<Game>();

            let action_request = s.take_from_address<ActionRequest<BuyArgument>>(
                object::id_address(&game),
            );
            let buy_argument_opt = action_request.action_request_parameters();

            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (player_balance, house_price, level, purchased) = buy_argument.buy_argument_info();
            assert!(player_balance == 2045 + 100);
            assert!(house_price == 30);
            assert!(level == 0);
            assert!(purchased == true);
            // server settled buy action state
            house_cell::settle_buy_for_testing(action_request, &mut game, ctx(s));
            // check player balance, house, pos_index
            let player_balance = game.player_balance(c).value();
            assert!(player_balance == 2145 - 30);
            assert!(game.player_position_of(c) == 2);

            let house_cell: &HouseCell = game.borrow_cell<HouseCell>(2);
            assert!(house_cell.house_cell_owner().extract() == c);
            assert!(house_cell.level() == 1);
            assert!(game.current_round() == 2);
            assert!(game.plays() == 10);

            s.return_to_sender(game);
        };

        // === player D turn ===

        s.next_tx(d);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move(&random, ctx(s));
            assert!(moved_steps == 2);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            // player_d pay "45" toll to player_c
            let mut action_request = game.request_player_move_for_testing<BuyArgument>(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.drop_action_request(action_request, ctx(s));

            assert!(game.player_position_of(d) == 2);
            assert!(game.current_round() == 2);
            assert!(game.plays() == 11);

            // player_balance;
            assert!(game.player_balance(d).value() == 2000 - 45);
            assert!(game.player_balance(c).value() == 2115 + 45);

            s.return_to_sender(game);

            game_id
        };

        // === player E turn ===

        s.next_tx(e);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            // cheating; test upgrade house :p
            let moved_steps = turn_cap.player_move_for_testing(17);
            assert!(moved_steps == 17);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            let mut action_request = game.request_player_move_for_testing<BuyArgument>(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            // upgrade
            game.request_player_action(action_request);
            let game_id = object::id(&game);

            // recieve salary
            assert!(game.player_balance(e).value() == 1920 + 100);

            s.return_to_sender(game);

            game_id
        };

        s.next_tx(e);
        {
            let action_request = s.take_from_sender<ActionRequest<BuyArgument>>();
            let (game_id_, player, new_pos_idx) = action_request.action_request_info();

            // check action_request info
            assert!(game_id == game_id_);
            assert!(player == e);
            assert!(new_pos_idx == 3);
            assert!(action_request.action_request_settled() == false);
            // checkw dynamic argument
            let buy_argument_opt = action_request.action_request_parameters<BuyArgument>();
            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (player_balance, house_price, level, purchased) = buy_argument.buy_argument_info();
            assert!(player_balance == 2020);
            assert!(house_price == 90);
            assert!(level == 1);
            assert!(purchased == false);

            action_request.execute_buy_action(true, ctx(s));
        };

        s.next_tx(admin);
        {
            let mut game = s.take_from_sender<Game>();

            let action_request = s.take_from_address<ActionRequest<BuyArgument>>(
                object::id_address(&game),
            );
            let buy_argument_opt = action_request.action_request_parameters();

            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (player_balance, house_price, level, purchased) = buy_argument.buy_argument_info();
            assert!(player_balance == 2020);
            assert!(house_price == 90);
            assert!(level == 1);
            assert!(purchased == true);
            // server settled buy action state
            house_cell::settle_buy_for_testing(action_request, &mut game, ctx(s));
            // check player balance, house, pos_index
            let player_balance = game.player_balance(e).value();
            assert!(player_balance == 2020 - 90);
            assert!(game.player_position_of(e) == 3);

            let house_cell: &HouseCell = game.borrow_cell<HouseCell>(3);
            assert!(house_cell.house_cell_owner().extract() == e);
            assert!(house_cell.level() == 2);
            assert!(game.current_round() == 3);
            assert!(game.plays() == 12);

            s.return_to_sender(game);
        };

        // === player B turn ===

        s.next_tx(b);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move_for_testing(12);
            assert!(moved_steps == 12);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            // player_b pay "135" toll to player_e
            let mut action_request = game.request_player_move_for_testing<BuyArgument>(
                turn_cap,
                ctx(s),
            );

            action_request.initialize_buy_params(&mut game);
            game.drop_action_request(action_request, ctx(s));
            assert!(game.player_position_of(b) == 3);
            assert!(game.current_round() == 3);
            assert!(game.plays() == 13);

            // player_balance;
            // recieve salary and pay the poll
            assert!(game.player_balance(b).value() == 1795 + 100 - 135);
            assert!(game.player_balance(e).value() == 1930 + 135);

            s.return_to_sender(game);

            game_id
        };

        // === player C turn ===

        s.next_tx(c);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move_for_testing(3);
            assert!(moved_steps == 3);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            let mut action_request = game.request_player_move_for_testing<DoNothingArgument>(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_do_nothing_params(&game);
            game.drop_action_request(action_request, ctx(s));

            assert!(game.player_position_of(c) == 5);
            assert!(game.current_round() == 3);
            assert!(game.plays() == 14);
            assert!(game.player_balance(c).value() == 2160);

            s.return_to_sender(game);

            game_id
        };

        // === player D turn ===

        s.next_tx(d);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move_for_testing(3);
            assert!(moved_steps == 3);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            // we've already known the moved_steps and corresponding action then, therefore we can config the PTB for requried generic parameters
            let mut action_request = game.request_player_move_for_testing<DoNothingArgument>(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_do_nothing_params(&game);
            game.drop_action_request(action_request, ctx(s));

            assert!(game.player_position_of(d) == 5);
            assert!(game.current_round() == 3);
            assert!(game.plays() == 15);
            assert!(game.player_balance(d).value() == 1955);

            s.return_to_sender(game);

            game_id
        };

        // === player E turn ===

        s.next_tx(e);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move_for_testing(20);
            assert!(moved_steps == 20);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            // upgrade to the max level
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            let mut action_request = game.request_player_move_for_testing<BuyArgument>(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.request_player_action(action_request);
            let game_id = object::id(&game);

            // we won't recieve salary as we're cheating :p
            assert!(game.player_balance(e).value() == 2065);

            s.return_to_sender(game);

            game_id
        };

        s.next_tx(e);
        {
            let action_request = s.take_from_sender<ActionRequest<BuyArgument>>();
            let (game_id_, player, new_pos_idx) = action_request.action_request_info();

            // check action_request info
            assert!(game_id == game_id_);
            assert!(player == e);
            assert!(new_pos_idx == 3);
            assert!(action_request.action_request_settled() == false);
            // checkw dynamic argument
            let buy_argument_opt = action_request.action_request_parameters<BuyArgument>();
            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (player_balance, house_price, level, purchased) = buy_argument.buy_argument_info();
            assert!(player_balance == 2065);
            assert!(house_price == 270);
            assert!(level == 2);
            assert!(purchased == false);

            action_request.execute_buy_action(true, ctx(s));
        };

        s.next_tx(admin);
        {
            let mut game = s.take_from_sender<Game>();

            let action_request = s.take_from_address<ActionRequest<BuyArgument>>(
                object::id_address(&game),
            );
            let buy_argument_opt = action_request.action_request_parameters();

            assert!(buy_argument_opt.is_some());

            let buy_argument = buy_argument_opt.borrow();
            let (player_balance, house_price, level, purchased) = buy_argument.buy_argument_info();
            assert!(player_balance == 2065);
            assert!(house_price == 270);
            assert!(level == 2);
            assert!(purchased == true);
            // server settled buy action state
            house_cell::settle_buy_for_testing(action_request, &mut game, ctx(s));
            // check player balance, house, pos_index
            let player_balance = game.player_balance(e).value();
            assert!(player_balance == 2065 - 270);
            assert!(game.player_position_of(e) == 3);

            let house_cell: &HouseCell = game.borrow_cell<HouseCell>(3);
            assert!(house_cell.house_cell_owner().extract() == e);
            assert!(house_cell.level() == 3);
            assert!(game.current_round() == 4);
            assert!(game.plays() == 16);

            s.return_to_sender(game);
        };

        // === player B turn ===

        s.next_tx(b);
        {
            // make player_b bankrupt
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move_for_testing(20);
            assert!(moved_steps == 20);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            // burn player's balance
            let player_balance = game.player_balance(b).value();
            let balance_manager = game.balance_mut().sub_balance(b, player_balance - 100);

            // player_b should pay "405" toll to player_e but only remain 100
            let mut action_request = game.request_player_move_for_testing<BuyArgument>(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.drop_action_request(action_request, ctx(s));

            assert!(game.player_position_of(b) == 3);
            assert!(game.current_round() == 4);
            assert!(game.plays() == 17);

            // player_balance;
            assert!(game.player_balance(b).value() == 0);
            assert!(game.player_balance(e).value() == 1795 + 100);

            s.return_to_sender(game);

            game_id
        };

        // === player C turn ===

        s.next_tx(c);
        {
            // make player_b bankrupt
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move_for_testing(18);
            assert!(moved_steps == 18);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            // player_c should pay "405" toll to player_e but only remain 100
            let mut action_request = game.request_player_move_for_testing<BuyArgument>(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.drop_action_request(action_request, ctx(s));

            assert!(game.player_position_of(c) == 3);
            assert!(game.current_round() == 4);
            assert!(game.plays() == 18);

            // pay the toll + recieve salary
            assert!(game.player_balance(c).value() == 2160 + 100 - 405);
            assert!(game.player_balance(e).value() == 1895 + 405);

            s.return_to_sender(game);

            game_id
        };

        // === player D turn ===

        s.next_tx(d);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move_for_testing(5);
            assert!(moved_steps == 5);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            // we've already known the moved_steps and corresponding action then, therefore we can config the PTB for requried generic parameters
            let mut action_request = game.request_player_move_for_testing<DoNothingArgument>(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_do_nothing_params(&game);
            game.drop_action_request(action_request, ctx(s));

            assert!(game.player_position_of(d) == 10);
            assert!(game.current_round() == 4);
            assert!(game.plays() == 19);
            assert!(game.player_balance(d).value() == 1955);

            s.return_to_sender(game);

            game_id
        };

        (scenario, clock)
    }

    #[test]
    fun test_monopoly_basic() {
        let (mut scenario, mut clock) = breakpoint_1();
        let (admin, b, c, d, e) = people();
        let s = &mut scenario;

        // === player E turn ===

        s.next_tx(e);
        {
            let random = s.take_shared<Random>();
            let mut turn_cap = s.take_from_sender<TurnCap>();

            let moved_steps = turn_cap.player_move_for_testing(20);
            assert!(moved_steps == 20);

            test::return_shared(random);
        };

        s.next_tx(admin);
        let game_id = {
            let mut game = s.take_from_sender<Game>();
            let turn_cap = s.take_from_address<TurnCap>(object::id_address(&game));

            // player_e should not upgrade anymore
            let mut action_request = game.request_player_move_for_testing<BuyArgument>(
                turn_cap,
                ctx(s),
            );
            action_request.initialize_buy_params(&mut game);
            game.drop_action_request(action_request, ctx(s));

            // player_balance;
            let player_balance = game.player_balance(e).value();
            assert!(player_balance == 2300);
            assert!(game.player_position_of(e) == 3);

            let house_cell: &HouseCell = game.borrow_cell<HouseCell>(3);
            assert!(house_cell.house_cell_owner().extract() == e);
            assert!(house_cell.level() == 3);
            assert!(game.current_round() == 5);
            assert!(game.plays() == 20);

            let game_id = object::id(&game);

            s.return_to_sender(game);

            game_id
        };

        // === Game Finish ===

        s.next_tx(admin);
        {
            let mut game = s.take_from_sender<Game>();

            // remove all the cells
            20u64.do!(|idx: u64| {
                // cells order
                if (idx % 5 == 0) {
                    let cell: Cell = game.remove_cell(idx);
                    cell.drop_cell();
                } else {
                    let cell: HouseCell = game.remove_cell(idx);
                    cell.drop_house_cell();
                };
            });

            let winners = game.drop();
            assert!(winners == vector[e]);
        };

        scenario.end();
        clock.destroy_for_testing();
    }
}
