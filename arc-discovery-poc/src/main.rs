use libp2p::{
    core::{PeerRecord, SignedEnvelope},
    identity::Keypair,
    Multiaddr,
};
use std::time::Instant;

fn verify_all(records: &[Vec<u8>]) -> (usize, std::time::Duration) {
    let start = Instant::now();
    let mut ok = 0usize;
    for bytes in records {
        if SignedEnvelope::from_protobuf_encoding(bytes)
            .ok()
            .and_then(|env| PeerRecord::from_signed_envelope(env).ok())
            .is_some()
        {
            ok += 1;
        }
    }
    (ok, start.elapsed())
}

fn main() {
    // Discovery RPC max is 10 MiB. Stay below it to show the request is wire-admissible
    // even after request framing/CBOR overhead.
    const TARGET_BYTES: usize = 9 * 1024 * 1024;
    const CAP: usize = 100;

    let addr: Multiaddr = "/ip4/203.0.113.1/tcp/26656".parse().unwrap();
    let mut records: Vec<Vec<u8>> = Vec::new();
    let mut raw_record_bytes = 0usize;

    while raw_record_bytes < TARGET_BYTES {
        let kp = Keypair::generate_ed25519();
        let record = PeerRecord::new(&kp, vec![addr.clone()]).unwrap();
        let encoded = record.into_signed_envelope().into_protobuf_encoding();
        raw_record_bytes += encoded.len();
        records.push(encoded);
    }

    println!("records={}", records.len());
    println!("raw_record_bytes={}", raw_record_bytes);
    println!("avg_record_bytes={:.2}", raw_record_bytes as f64 / records.len() as f64);

    // This mirrors handle_peers_request's received_peer_ids pre-pass:
    // it scans ALL records before process_signed_peer_records applies .take(cap).
    let (all_ok, full_elapsed) = verify_all(&records);
    let (cap_ok, cap_elapsed) = verify_all(&records[..CAP.min(records.len())]);

    // Actual current handler does full pre-pass PLUS capped processing, so model both.
    let total_current = full_elapsed + cap_elapsed;

    println!("full_prepass_verified={all_ok}");
    println!("full_prepass_ms={:.3}", full_elapsed.as_secs_f64() * 1000.0);
    println!("cap100_verified={cap_ok}");
    println!("cap100_ms={:.3}", cap_elapsed.as_secs_f64() * 1000.0);
    println!("current_handler_crypto_ms={:.3}", total_current.as_secs_f64() * 1000.0);
    println!(
        "verification_amplification_vs_intended_cap={:.2}x",
        full_elapsed.as_secs_f64() / cap_elapsed.as_secs_f64().max(f64::MIN_POSITIVE)
    );
    println!(
        "six_allowed_requests_crypto_s={:.3}",
        total_current.as_secs_f64() * 6.0
    );

    assert!(records.len() > CAP);
    assert_eq!(all_ok, records.len());
    assert_eq!(cap_ok, CAP);
}
