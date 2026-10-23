//! 联网检查：推荐播客与节目能否正常解析（不需要登录）
#[tokio::main]
async fn main() {
    let c = ncm_api::Client::new(Default::default()).unwrap();
    c.set_real_ip(Some("116.25.66.132".into()));
    let r = c.recommend_radios(4).await.unwrap();
    println!("radios: {}", r.len());
    for x in &r {
        println!(
            "  {} {} / {:?}",
            x.id,
            x.name,
            x.dj.as_ref().map(|d| &d.nickname)
        );
    }
    if let Some(x) = r.first() {
        let (p, total) = c.radio_programs(x.id, 0, 3).await.unwrap();
        println!("programs: {} of {total}", p.len());
    }
}
