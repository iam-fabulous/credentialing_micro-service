#[allow(unused_use, lint(share_owned))]
module credentialing::cert {
    use sui::package;
    use sui::display;
    use sui::event;
    use std::string::String;
    // use credentialing::cert::Credential;
    // use credentialing::cert::VERSION;


    /// Not the right admin for this counter
    const ENotAdmin: u64 = 0;
    /// Calling functions from the wrong package version
    const EWrongVersion: u64 = 2;

    // 1. Track the current version of the module
    const VERSION: u64 = 1;

    /// The OTW (One-Time Witness) for the publisher object.
    public struct CERT has drop{}

    public struct Credential has key {
        id: UID,
        recipient_name: String,
        course_name: String,
        issue_date: String,
        issuer: String,
        walrus_blob_id: String,
        version: u64
    }

    public struct AdminCap has key, store {
        id: UID,
        admin: address,
    }

    public struct MintEvent has copy, drop {
        credential_id: ID,
        recipient: address,
        blob_id: String,
    }

    fun assert_admin(_cap: &AdminCap, ctx: &TxContext) {
        assert!(_cap.admin == ctx.sender(), ENotAdmin);
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
        transfer::transfer(AdminCap { id: object::new(ctx), admin: ctx.sender() }, ctx.sender());
    }

    //--- Public Functions ---

    /// Mint a new Soulbound Credential NFT to the recipient address.
    /// Can only be called by an entity holding the AdminCap.
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
        assert_admin(_cap, ctx);
        let id = object::new(ctx);
        let credential_id = id.to_inner();

        let credential = Credential {
            id,
            recipient_name,
            course_name,
            issue_date,
            issuer,
            walrus_blob_id: copy walrus_blob_id,
            version: VERSION,
        };

        // Emit event for off-chain indexing
        event::emit(MintEvent {
            credential_id,
            recipient,
            blob_id: walrus_blob_id,
        });
        // Transfer the credential to the recipient
        transfer::transfer(credential, recipient);
    }


    public entry fun migrate_credential(
        _cap: &AdminCap,
        credential: &mut Credential,
        display: &mut display::Display<Credential>,
        ctx: &mut TxContext,
    ){
        assert_admin(_cap, ctx);
        assert!(credential.version < VERSION, EWrongVersion);
        credential.version = VERSION;

        display.edit<Credential>(
            b"link".to_string(),
            b"https://aggregator.walrus-testnet.walrus.space/v1/blobs/{walrus_blob_id}".to_string(),
        );

        display.edit<Credential>(
            b"image_url".to_string(),
            b"https://aggregator.walrus-testnet.walrus.space/v1/blobs/{walrus_blob_id}".to_string(),
        )
    }

    // Burn a Credential object(Revoke).
    // Can only be called by an entity holding the AdminCap.
    // 
    // public fun burn_credential(_cap: &AdminCap, credential: Credential) {
    //     let Credential { id, .. } = credential;
    //     object::delete(id);
    // }

    // --- Test Functions (Only compiled for tests) ---

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        let otw = CERT {}; // Create the OTW
        init(otw, ctx);    // Call the real init
    }
}