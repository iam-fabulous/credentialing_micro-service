#[allow(unused_use, lint(share_owned), unused_variable)]
module credentialing::cert {
    use sui::package;
    use sui::display;
    use sui::event;
    use std::string::String;


    // --- ERRORS ---
    const EWrongVersion: u64 = 1;
    const EDeprecated: u64 = 999;



    // --- CONSTANTS ---
    const MODULE_VERSION: u64 = 1;



    // --- STRUCTS ---
    /// The OTW (One-Time Witness) for the publisher object.
    public struct CERT has drop{}


    public struct Credential has key {
        id: UID,
        recipient_name: String,
        course_name: String,
        issue_date: String,
        issuer: String,
        walrus_blob_id: String,
    }

    public struct AdminCap has key, store {
        id: UID,
    }

    public struct MintEvent has copy, drop {
        credential_id: ID,
        recipient: address,
        blob_id: String,
    }

    public struct Version has key {
        id: UID,
        version: u64
    }


    fun init (otw: CERT, ctx: &mut sui::tx_context::TxContext) {
        let publisher = package::claim(otw, ctx);

        let keys = vector[
            b"name".to_string(),
            b"link".to_string(),
            b"image_url".to_string(),
            b"description".to_string(),
            b"project_url".to_string(),
            b"creator".to_string(),
        ];

        let values = vector[
            b"{recipient_name} -{course_name}".to_string(),
            b"https://aggregator.walrus-testnet.walrus.space/v1/blobs/{walrus_blob_id}".to_string(),
            b"https://aggregator.walrus-testnet.walrus.space/v1/blobs/{walrus_blob_id}".to_string(),
            b"Certified completion of {course_name} issued to {recipient_name} on {issue_date} by {issuer}".to_string(),
            b"https://example.com/courses/{course_name}".to_string(),
            b"{issuer}".to_string(),
        ];

        let mut display = display::new_with_fields<Credential>(
            &publisher,
            keys,
            values,
            ctx,
        );

        display.update_version();

        transfer::public_share_object(display);

        transfer::public_transfer(publisher, ctx.sender());
        transfer::transfer(AdminCap { id: object::new(ctx) }, ctx.sender());
    }


    // --- ADMIN FUNCTIONS ---

    // Run once after upgrade to start versioning
    public fun create_version_object(_cap: &AdminCap, ctx: &mut TxContext) {
        transfer::share_object(Version {
            id: object::new(ctx),
            version: MODULE_VERSION,
        });
    }

    public fun update_version(_cap: &AdminCap, version: &mut Version, new_version: u64) {
        version.version = new_version;
    }

    // Add the display migration function here too (from previous answer)
    public fun update_display_urls(_cap: &AdminCap, display: &mut display::Display<Credential>) {
        display.edit<Credential>(
            b"link".to_string(),
            b"https://aggregator.walrus-testnet.walrus.space/v1/blobs/{walrus_blob_id}".to_string(),
        );

        display.edit<Credential>(
            b"image_url".to_string(),
            b"https://aggregator.walrus-testnet.walrus.space/v1/blobs/{walrus_blob_id}".to_string(),
        );

        display.update_version();
    }


    //--- MINTING ---

    // Mint a new Soulbound Credential NFT to the recipient address.
    // Can only be called by an entity holding the AdminCap.
    // DEPRECATED: Use mint_credential_v2 instead.
    public fun mint_credential(
        _cap: &AdminCap,
        recipient: address,
        recipient_name: String,
        course_name: String,
        issue_date: String,
        issuer: String,
        walrus_blob_id: String,
        ctx: &mut TxContext,
    ){
        abort EDeprecated
    }


    // 2. New Function (V2) uses the external Version module
    public fun mint_credential_v2(
        _cap: &AdminCap,
        version: &Version,
        recipient: address,
        recipient_name: String,
        course_name: String,
        issue_date: String,
        issuer: String,
        walrus_blob_id: String,
        ctx: &mut TxContext,
    ){
        assert!(version.version == MODULE_VERSION, EWrongVersion);

        let id = object::new(ctx);
        let credential_id = id.to_inner();

        let credential = Credential {
            id,
            recipient_name,
            course_name,
            issue_date,
            issuer,
            walrus_blob_id: copy walrus_blob_id,
        };

        event::emit(MintEvent {
            credential_id,
            recipient,
            blob_id: walrus_blob_id,
        });

        transfer::transfer(credential, recipient);
    }
    
    


    
    // --- Test Functions (Only compiled for tests) ---

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        let otw = CERT {}; // Create the OTW
        init(otw, ctx);    // Call the real init
    }
}