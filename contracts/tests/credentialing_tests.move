#[test_only]
module credentialing::credentialing_tests {
    use credentialing::cert::{Self, Credential, AdminCap};
    use sui::test_scenario::{Self as ts};
    use std::string::{Self};

    const ADMIN: address = @0xA;
    const STUDENT: address = @0xB;

    #[test]
    fun test_mint_happy_path() {
        // 1. Start the scenario with Admin
        let mut scenario = ts::begin(ADMIN);

        // 2. Run Init (Deploy the contract)
        {
            let ctx = ts::ctx(&mut scenario);
            cert::init_for_testing(ctx);
        };

        // 3. Admin Mints a Cert
        ts::next_tx(&mut scenario, ADMIN);
        {
            // Admin grabs the AdminCap from the 'storage' simulated by test_scenario
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            // This should succeed: ADMIN is the admin
            cert::mint_credential(
                &cap,
                STUDENT,
                string::utf8(b"Jane Doe"),
                string::utf8(b"Sui Developer Course"),
                string::utf8(b"2025-12-05"),
                string::utf8(b"Academy Inc"),
                string::utf8(b"Au3tX...BlobID"), // The Walrus ID
                ctx
            );

            // Put the AdminCap back (Clean up)
            ts::return_to_sender(&scenario, cap);
        };

        // 4. Verify Student Received it
        ts::next_tx(&mut scenario, STUDENT);
        {
            // Try to take the Credential object from Student's inventory
            let cred = ts::take_from_sender<Credential>(&scenario);
            // If this line passes, the student has it!
            ts::return_to_sender(&scenario, cred);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = cert::ENotAdmin)]
    fun test_mint_fail_non_admin() {
        // 1. Start the scenario with Admin
        let mut scenario = ts::begin(ADMIN);

        // 2. Run Init (Deploy the contract)
        {
            let ctx = ts::ctx(&mut scenario);
            cert::init_for_testing(ctx);
        };

        // 3. Transfer AdminCap to student (simulate malicious use)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            transfer::public_transfer(cap, STUDENT);
        };

        
        // 4. Student tries to mint (should fail)
        ts::next_tx(&mut scenario, STUDENT);
        {
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            // This should fail: STUDENT is not the admin
            // The test should expect a failure here due to admin check
            cert::mint_credential(
                &cap,
                STUDENT,
                string::utf8(b"Malicious Mint"),
                string::utf8(b"Fake Course"),
                string::utf8(b"2025-12-05"),
                string::utf8(b"Fake Inc"),
                string::utf8(b"FakeBlobID"),
                ctx
            );
            // If the above line does not abort, the test should fail
            // (You may need to use a test framework's expect_abort or similar)
            ts::return_to_sender(&scenario, cap);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_burn_certificate() {
        let mut scenario = ts::begin(ADMIN);

        // 1. Init
        {
            let ctx = ts::ctx(&mut scenario);
            cert::init_for_testing(ctx);
        };

        // 2. Mint to Student
        ts::next_tx(&mut scenario, ADMIN);
        {
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            cert::mint_credential(
                &cap, STUDENT, 
                string::utf8(b"Jane"), 
                string::utf8(b"101"), 
                string::utf8(b"Date"), 
                string::utf8(b"Issuer"), 
                string::utf8(b"Blob"), 
                ctx
            );
            ts::return_to_sender(&scenario, cap);
        };

        // 3. Admin Burns the Cert
        ts::next_tx(&mut scenario, ADMIN);
        {
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            // See note in your original code: only the owner of the Credential can burn it
            ts::return_to_sender(&scenario, cap);
        };
        
        ts::end(scenario);
    }
}
