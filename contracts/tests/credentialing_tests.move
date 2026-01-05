#[test_only]
module credentialing::credentialing_tests {
    use credentialing::cert::{Self, Credential, AdminCap, Version};
    use sui::test_scenario::{Self as ts};
    use std::string;

    const ADMIN: address = @0xA;
    const STUDENT: address = @0xB;

    // --- HELPER TO SETUP V2 ENVIRONMENT ---
    fun setup_test(scenario: &mut ts::Scenario) {
        // 1. Run Init (Deploys OneTimeWitness logic)
        {
            let ctx = ts::ctx(scenario);
            cert::init_for_testing(ctx);
        };

        // 2. Create the Version Object (Manual step required in V2)
        ts::next_tx(scenario, ADMIN);
        {
            let cap = ts::take_from_sender<AdminCap>(scenario);
            let ctx = ts::ctx(scenario);
            
            cert::create_version_object(&cap, ctx);

            ts::return_to_sender(scenario, cap);
        };
    }

    #[test]
    fun test_mint_v2_happy_path() {
        let mut scenario = ts::begin(ADMIN);
        setup_test(&mut scenario);

        // 3. Admin Mints a Cert using V2
        ts::next_tx(&mut scenario, ADMIN);
        {
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            // We must take the shared Version object
            let version = ts::take_shared<Version>(&scenario); 
            let ctx = ts::ctx(&mut scenario);

            cert::mint_credential_v2(
                &cap,
                &version, // Pass the version object
                STUDENT,
                string::utf8(b"Jane Doe"),
                string::utf8(b"Sui Developer Course"),
                string::utf8(b"2025-12-05"),
                string::utf8(b"Academy Inc"),
                string::utf8(b"Au3tX...BlobID"),
                ctx
            );

            ts::return_to_sender(&scenario, cap);
            ts::return_shared(version);
        };

        // 4. Verify Student Received it
        ts::next_tx(&mut scenario, STUDENT);
        {
            let cred = ts::take_from_sender<Credential>(&scenario);
            // Optional: Check fields here if you want
            ts::return_to_sender(&scenario, cred);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = cert::EWrongVersion)]
    fun test_mint_fails_on_wrong_version() {
        let mut scenario = ts::begin(ADMIN);
        setup_test(&mut scenario);

        // 3. Admin updates version to '2' (simulating a future state)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut version = ts::take_shared<Version>(&scenario);
            
            // Update global version to 2
            cert::update_version(&cap, &mut version, 2);

            ts::return_to_sender(&scenario, cap);
            ts::return_shared(version);
        };

        // 4. Try to Mint (Should Fail because contract expects Version 1)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let version = ts::take_shared<Version>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            cert::mint_credential_v2(
                &cap,
                &version, 
                STUDENT,
                string::utf8(b"Jane Doe"),
                string::utf8(b"Sui Developer Course"),
                string::utf8(b"2025-12-05"),
                string::utf8(b"Academy Inc"),
                string::utf8(b"Au3tX...BlobID"),
                ctx
            ); // <--- ABORTS HERE

            ts::return_to_sender(&scenario, cap);
            ts::return_shared(version);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = cert::EDeprecated)]
    fun test_old_mint_is_deprecated() {
        let mut scenario = ts::begin(ADMIN);
        setup_test(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            // Attempt to call the old function
            cert::mint_credential(
                &cap,
                STUDENT,
                string::utf8(b"Old"),
                string::utf8(b"Old"),
                string::utf8(b"Old"),
                string::utf8(b"Old"),
                string::utf8(b"Old"),
                ctx
            ); // <--- ABORTS HERE

            ts::return_to_sender(&scenario, cap);
        };
        ts::end(scenario);
    }
}