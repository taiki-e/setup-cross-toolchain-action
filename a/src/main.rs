fn main() {
    let mut args = std::env::args();
    let exe = args.next().unwrap();
    assert!(
        exe.ends_with(&format!("a{}", std::env::consts::EXE_SUFFIX)),
        "{exe}"
    );
    assert_eq!("a", args.next().unwrap());
    assert_eq!("b", args.next().unwrap());
    assert_eq!(None, args.next());
}
