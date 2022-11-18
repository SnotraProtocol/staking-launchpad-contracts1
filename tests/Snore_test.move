#[test_only]
module snore::snore_test{
    use aptos_framework::string;
    use aptos_framework::signer;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::managed_coin;
    use aptos_framework::coin::{Self, MintCapability, BurnCapability};
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_token::token;

    use snore::snore;

    struct AptosCoinTest has key{
      mint_cap: MintCapability<AptosCoin>,
      burn_cap: BurnCapability<AptosCoin>
   }

   #[test(admin = @snore, creator = @0x111, collection_creator = @0x123, aptos_framework = @aptos_framework)]
    public entry fun test_startPool(
        admin: &signer,
        creator: &signer,
        collection_creator: &signer,
        aptos_framework: &signer
    ){
        let collection_name:vector<u8> =  b"collection";
        let collection_desc:vector<u8> = b"collection_desc";
        let collection_img_url:vector<u8> = b"collection_img_url";

        let twitter_url: vector<u8> = b"twitter_url";
        let discord_url: vector<u8> = b"discord_url";
        let telegram_url: vector<u8> = b"telegram_url";
        let medium_url: vector<u8> = b"medium_url";
        let github_url: vector<u8> = b"github_url";


        let nft_total_count:u64 = 10;
        let staking_duration:u64 = 864000; //in seconds  10 days
        let reward_per_day:u64 = 10;
        let deposit_coin_amount:u64 = 1000;

        let creator_addr = signer::address_of(creator);
        account::create_account_for_test(creator_addr);
        //mint 10000 coin for creator
        let ( burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        let coins_minted = coin::mint<AptosCoin>(10000, &mint_cap);

        if (!coin::is_account_registered<AptosCoin>(creator_addr)){
	      managed_coin::register<AptosCoin>(creator);
        };

        coin::deposit<AptosCoin>(creator_addr, coins_minted);

        move_to(creator, AptosCoinTest{
            mint_cap,
            burn_cap
        });

        account::create_account_for_test(signer::address_of(admin));

        snore::initSnore(admin);

        account::create_account_for_test(signer::address_of(collection_creator));
        // create collection for testing
        token::create_collection(
            collection_creator,
            string::utf8(b"collection"), //collection_name
            string::utf8(b""), //description
            string::utf8(b""),//uri
            100,
            vector<bool>[false, false, false]
        );

        snore::startPool<AptosCoin>(
            creator,
            signer::address_of(collection_creator),
            collection_name,
            collection_desc,
            collection_img_url,
            nft_total_count,
            staking_duration,
            reward_per_day,
            deposit_coin_amount,
            twitter_url,
            discord_url,
            telegram_url,
            medium_url,
            github_url
        );

        let snore_pool_signer = snore::get_resource_account(1);
        assert!(coin::balance<AptosCoin>(signer::address_of(&snore_pool_signer)) == 1000, 1);
    }
    // create  test token for user
    fun test_create_token_for_user(
        creator:&signer,
        user: &signer,
        collection_creator: &signer,
        collection_name: string::String,
        token_name: string::String
    ) acquires AptosCoinTest
    {
        //mint 10000 aptos token to user
        let aptosCoinTest = borrow_global<AptosCoinTest>(signer::address_of(creator));
        let coins_minted = coin::mint<AptosCoin>(10000, &aptosCoinTest.mint_cap);
        let user_addr = signer::address_of(user);
        if (!coin::is_account_registered<AptosCoin>(user_addr)){
	      managed_coin::register<AptosCoin>(user);
        };
        coin::deposit<AptosCoin>(user_addr, coins_minted);

        token::create_token_script(
            collection_creator,
            collection_name,
            token_name,
            string::utf8(b""),
            1,
            1,
            string::utf8(b""),
            signer::address_of(collection_creator),
            100,
            0,
            vector<bool>[ false, false, false, false, false, false ],
            vector<string::String>[],
            vector<vector<u8>>[],
             vector<string::String>[]
        );
        let token_data_id = token::create_token_data_id(signer::address_of(collection_creator), collection_name, token_name);
        let token_id = token::create_token_id(token_data_id, 0);
        token::direct_transfer(collection_creator,user, token_id, 1);
    }
    #[test(admin = @snore, creator = @0x111, user = @0x456, collection_creator= @0x123, aptos_framework = @aptos_framework)]
    public entry fun test_stake(admin: &signer, creator: &signer, user: &signer, collection_creator: &signer, aptos_framework: &signer)
     acquires AptosCoinTest
     {
        test_startPool(admin, creator, collection_creator, aptos_framework);
        account::create_account_for_test(signer::address_of(user));
        test_create_token_for_user(creator, user, collection_creator, string::utf8(b"collection"), string::utf8(b"token1"));

        //stake
        timestamp::set_time_has_started_for_testing(aptos_framework);
        snore::stake<AptosCoin>(user, 1, b"token1");
        let token_id = token::create_token_id_raw(signer::address_of(collection_creator), string::utf8(b"collection"), string::utf8(b"token1"),0);
        assert!( token::balance_of(signer::address_of(user), token_id) ==0, 1);

        let snore_pool_signer = snore::get_resource_account(1);
        assert!( token::balance_of(signer::address_of(&snore_pool_signer), token_id) ==1, 1);


    }
    #[test(admin = @snore, creator = @0x111, user = @0x456, collection_creator= @0x123, aptos_framework = @aptos_framework)]
    public entry fun test_unstake(admin: &signer, creator: &signer, user: &signer, collection_creator: &signer, aptos_framework: &signer)
     acquires AptosCoinTest
    {
        test_stake(admin, creator, user, collection_creator, aptos_framework);
        snore::unstake<AptosCoin>(user, 1, b"token1");
        let token_id = token::create_token_id_raw(signer::address_of(collection_creator), string::utf8(b"collection"), string::utf8(b"token1"),0);
        assert!( token::balance_of(signer::address_of(user), token_id) ==1, 1);
        let snore_pool_signer = snore::get_resource_account(1);
        assert!( token::balance_of(signer::address_of(&snore_pool_signer), token_id) == 0, 1);
    }

    #[test(admin = @snore, creator = @0x111, user = @0x456, collection_creator= @0x123, aptos_framework = @aptos_framework)]
    public entry fun test_claim(admin: &signer, creator: &signer, user: &signer, collection_creator: &signer, aptos_framework: &signer)
     acquires AptosCoinTest
    {
        test_stake(admin, creator, user, collection_creator, aptos_framework);

        let aptos_balance = coin::balance<AptosCoin>(signer::address_of(user));
        assert!(aptos_balance == 9000, 1);  //paid Fee 1000 in stake

        timestamp::fast_forward_seconds(86400);  //next 1 day.
        snore::claim<AptosCoin>(user, 1);
        let aptos_balance = coin::balance<AptosCoin>(signer::address_of(user));
        let rewarded = 10;
        assert!(aptos_balance == 9000 + rewarded - 1000, 1); // rewarded - FEE
    }

    #[test(admin = @snore, creator = @0x111, user = @0x456, collection_creator= @0x123, aptos_framework = @aptos_framework)]
    public entry fun test_withdraw(admin: &signer, creator: &signer, collection_creator: &signer, aptos_framework: &signer)
    {
        test_startPool(admin, creator, collection_creator, aptos_framework);
        assert!(coin::balance<AptosCoin>(signer::address_of(admin)) == 0, 1);
        snore::withdraw_from_pool<AptosCoin>(admin, 1, 100);
        assert!(coin::balance<AptosCoin>(signer::address_of(admin)) == 100, 1);

    }

    #[test(admin = @snore, creator = @0x111, user = @0x456, collection_creator= @0x123, aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = 6)] //CAN_NOT_STAKE
    public entry fun test_stop_staking(admin: &signer, creator: &signer, user: &signer, collection_creator: &signer, aptos_framework: &signer)
     acquires AptosCoinTest
    {
        test_startPool(admin, creator, collection_creator, aptos_framework);
        snore::stop_staking(creator, 1);
        account::create_account_for_test(signer::address_of(user));
        test_create_token_for_user(creator, user, collection_creator, string::utf8(b"collection"), string::utf8(b"token1"));
        timestamp::set_time_has_started_for_testing(aptos_framework);
        snore::stake<AptosCoin>(user, 1 ,b"token1");
    }


    #[test(admin = @snore, creator = @0x111, user = @0x456, collection_creator= @0x123, aptos_framework = @aptos_framework)]
    public entry fun claim_passed_duration(admin: &signer, creator: &signer, user: &signer, collection_creator: &signer, aptos_framework: &signer)
     acquires AptosCoinTest
    {
        test_stake(admin, creator, user, collection_creator, aptos_framework);

        let aptos_balance = coin::balance<AptosCoin>(signer::address_of(user));
        assert!(aptos_balance == 9000, 1);  //paid Fee 1000 in stake

        timestamp::fast_forward_seconds(86400 * 2);  //next 2 day.
        snore::claim<AptosCoin>(user, 1);
        let aptos_balance = coin::balance<AptosCoin>(signer::address_of(user));
        let rewarded = 10 * 2;
        assert!(aptos_balance == 9000 + rewarded - 1000, 1); // rewarded - FEE   8000 + 20 = 8020

        timestamp::fast_forward_seconds(86400 * 2);  //next 2 day.
        snore::claim<AptosCoin>(user, 1);
        let aptos_balance = coin::balance<AptosCoin>(signer::address_of(user));
        let rewarded = 10 * 2;
        assert!(aptos_balance == 8020 + rewarded - 1000, 1); // rewarded - FEE
    }


    #[test(admin = @snore, creator = @0x111, user = @0x456, collection_creator= @0x123, aptos_framework = @aptos_framework)]
    public entry fun unstake_passed_duration(admin: &signer, creator: &signer, user: &signer, collection_creator: &signer, aptos_framework: &signer)
     acquires AptosCoinTest
    {
        test_stake(admin, creator, user, collection_creator, aptos_framework);
        let aptos_balance = coin::balance<AptosCoin>(signer::address_of(user));
        assert!(aptos_balance == 9000, 1);  // 10000 - FEE(1000) = 9000
        timestamp::fast_forward_seconds(86400 * 2);  //next 2 day.
        snore::unstake<AptosCoin>(user, 1, b"token1");
        let aptos_balance = coin::balance<AptosCoin>(signer::address_of(user));
        let rewarded = 10* 2;
        assert!(aptos_balance == 9000 + rewarded - 1000, 1); // rewarded - FEE   8000 + 20 = 8020
    }


  #[test(admin = @snore, creator = @0x111, user = @0x456, collection_creator = @0x123, aptos_framework = @aptos_framework)]
    public entry fun test_startPool_double(
        admin: &signer,
        creator: &signer,
        user: &signer,
        collection_creator: &signer,
        aptos_framework: &signer
    ) acquires AptosCoinTest{
        let collection_name:vector<u8> =  b"collection";
        let collection_desc:vector<u8> = b"collection_desc";
        let collection_img_url:vector<u8> = b"collection_img_url";

        let collection_name1:vector<u8> =  b"collection1";
        let collection_desc1:vector<u8> = b"collection_desc1";
        let collection_img_url1:vector<u8> = b"collection_img_url1";

        let twitter_url: vector<u8> = b"twitter_url";
        let discord_url: vector<u8> = b"discord_url";
        let telegram_url: vector<u8> = b"telegram_url";
        let medium_url: vector<u8> = b"medium_url";
        let github_url: vector<u8> = b"github_url";

        let nft_total_count:u64 = 10;
        let staking_duration:u64 = 864000; //in seconds  10 days
        let reward_per_day:u64 = 10;
        let deposit_coin_amount:u64 = 1000;

        let creator_addr = signer::address_of(creator);
        account::create_account_for_test(creator_addr);
        //mint 10000 coin for creator
        let ( burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        let coins_minted = coin::mint<AptosCoin>(10000, &mint_cap);

        if (!coin::is_account_registered<AptosCoin>(creator_addr)){
	      managed_coin::register<AptosCoin>(creator);
        };

        coin::deposit<AptosCoin>(creator_addr, coins_minted);

        move_to(creator, AptosCoinTest{
            mint_cap,
            burn_cap
        });

        account::create_account_for_test(signer::address_of(admin));

        snore::initSnore(admin);

        account::create_account_for_test(signer::address_of(collection_creator));
        // create collection for testing
        token::create_collection(
            collection_creator,
            string::utf8(b"collection"), //collection_name
            string::utf8(b""), //description
            string::utf8(b""),//uri
            100,
            vector<bool>[false, false, false]
        );

        // create collection1 for testing
        token::create_collection(
            collection_creator,
            string::utf8(b"collection1"), //collection_name
            string::utf8(b""), //description
            string::utf8(b""),//uri
            100,
            vector<bool>[false, false, false]
        );

        snore::startPool<AptosCoin>(
            creator,
            signer::address_of(collection_creator),
            collection_name,
            collection_desc,
            collection_img_url,
            nft_total_count,
            staking_duration,
            reward_per_day,
            deposit_coin_amount,
            twitter_url,
            discord_url,
            telegram_url,
            medium_url,
            github_url
        );

        snore::startPool<AptosCoin>(
            creator,
            signer::address_of(collection_creator),
            collection_name1,
            collection_desc1,
            collection_img_url1,
            nft_total_count,
            staking_duration,
            reward_per_day,
            deposit_coin_amount,
            twitter_url,
            discord_url,
            telegram_url,
            medium_url,
            github_url
        );

        let snore_pool_signer = snore::get_resource_account(1);
        assert!(coin::balance<AptosCoin>(signer::address_of(&snore_pool_signer)) == 1000, 1);

        let snore_pool_signer1 = snore::get_resource_account(2);
        assert!(coin::balance<AptosCoin>(signer::address_of(&snore_pool_signer1)) == 1000, 1);

        //stake for pool_1
        account::create_account_for_test(signer::address_of(user));
        test_create_token_for_user(creator, user, collection_creator, string::utf8(b"collection"), string::utf8(b"token1"));

        //stake for pool_2
        test_create_token_for_user(creator, user, collection_creator, string::utf8(b"collection1"), string::utf8(b"token1"));

        timestamp::set_time_has_started_for_testing(aptos_framework);
        snore::stake<AptosCoin>(user, 1, b"token1");
        snore::stake<AptosCoin>(user, 2, b"token1");

        let token_id = token::create_token_id_raw(signer::address_of(collection_creator), string::utf8(b"collection"), string::utf8(b"token1"),0);
        assert!( token::balance_of(signer::address_of(user), token_id) ==0, 1);

        let snore_pool_signer = snore::get_resource_account(1);
        assert!( token::balance_of(signer::address_of(&snore_pool_signer), token_id) ==1, 1);

        let token_id1 = token::create_token_id_raw(signer::address_of(collection_creator), string::utf8(b"collection1"), string::utf8(b"token1"),0);
        assert!( token::balance_of(signer::address_of(user), token_id1) ==0, 1);

        let snore_pool_signer1 = snore::get_resource_account(2);
        assert!( token::balance_of(signer::address_of(&snore_pool_signer1), token_id1) ==1, 1);

        let aptos_balance = coin::balance<AptosCoin>(signer::address_of(user));
        assert!(aptos_balance == 18000, 1); //20000 - 2000  (FEE*2)

        timestamp::fast_forward_seconds(86400 * 2);  //next 2 day.
        snore::unstake<AptosCoin>(user, 1, b"token1");
        timestamp::fast_forward_seconds(86400 * 2);  //next 4 day.
        snore::unstake<AptosCoin>(user, 2, b"token1");

        let aptos_balance = coin::balance<AptosCoin>(signer::address_of(user));
        assert!(aptos_balance == 18000 - 2000 + 10 * 2 + 10 * 4, 1); // rewarded - FEE   16060

        timestamp::fast_forward_seconds(86400 * 2);  //next 2 day.
        //stake again
        snore::stake<AptosCoin>(user, 1, b"token1");


    }


}
