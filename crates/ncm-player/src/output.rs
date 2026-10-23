//! cpal 输出：解码线程写环形缓冲，音频回调读出并施加音量。
//!
//! 按音源的采样率与声道开流；PipeWire / WASAPI / AAudio 都会在系统侧做重采样。

use std::sync::Arc;
use std::sync::atomic::{AtomicBool, AtomicU32, AtomicU64, Ordering};

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use rtrb::{Producer, RingBuffer};

use crate::Error;

/// 解码线程与音频回调共享的状态。
#[derive(Default)]
pub struct Shared {
    /// f32 位模式
    pub volume: AtomicU32,
    pub paused: AtomicBool,
    /// 回调实际播放出去的帧数（用于计算进度）
    pub played_frames: AtomicU64,
    /// 解码线程递增以请求清空缓冲；回调处理后写回 `flush_ack`
    pub flush_req: AtomicU64,
    pub flush_ack: AtomicU64,
}

impl Shared {
    pub fn new(volume: f32) -> Arc<Self> {
        let s = Self::default();
        s.volume.store(volume.to_bits(), Ordering::Relaxed);
        Arc::new(s)
    }
}

pub struct Output {
    pub sample_rate: u32,
    pub channels: u16,
    producer: Producer<f32>,
    _stream: cpal::Stream,
}

impl Output {
    pub fn open(sample_rate: u32, channels: u16, shared: Arc<Shared>) -> Result<Self, Error> {
        let host = cpal::default_host();
        let device = host
            .default_output_device()
            .ok_or_else(|| Error::Output("no output device".into()))?;
        let config = cpal::StreamConfig {
            channels,
            sample_rate,
            buffer_size: cpal::BufferSize::Default,
        };
        // 约 0.5 秒缓冲：足够抗抖动，暂停/跳转的延迟也可接受
        let cap = (sample_rate as usize / 2) * channels as usize;
        let (producer, mut consumer) = RingBuffer::<f32>::new(cap);
        let ch = channels as u64;
        let s = shared.clone();
        let stream = device
            .build_output_stream::<f32, _, _>(
                config,
                move |data: &mut [f32], _| {
                    let req = s.flush_req.load(Ordering::Acquire);
                    if req != s.flush_ack.load(Ordering::Relaxed) {
                        let n = consumer.slots();
                        if let Ok(chunk) = consumer.read_chunk(n) {
                            chunk.commit_all();
                        }
                        s.flush_ack.store(req, Ordering::Release);
                    }
                    if s.paused.load(Ordering::Relaxed) {
                        data.fill(0.0);
                        return;
                    }
                    let vol = f32::from_bits(s.volume.load(Ordering::Relaxed));
                    let n = data.len().min(consumer.slots());
                    // 只消费整帧，避免左右声道错位
                    let n = n - n % ch as usize;
                    if let Ok(chunk) = consumer.read_chunk(n) {
                        let (a, b) = chunk.as_slices();
                        for (d, x) in data.iter_mut().zip(a.iter().chain(b)) {
                            *d = x * vol;
                        }
                        chunk.commit_all();
                    }
                    data[n..].fill(0.0);
                    s.played_frames.fetch_add(n as u64 / ch, Ordering::Relaxed);
                },
                |e| tracing::warn!("audio output error: {e}"),
                None,
            )
            .map_err(|e| Error::Output(e.to_string()))?;
        stream.play().map_err(|e| Error::Output(e.to_string()))?;
        Ok(Self { sample_rate, channels, producer, _stream: stream })
    }

    /// 尽可能多地写入，返回写入的样本数（总是整帧）。
    pub fn write(&mut self, samples: &[f32]) -> usize {
        let ch = self.channels as usize;
        let n = samples.len().min(self.producer.slots());
        let n = n - n % ch;
        if n == 0 {
            return 0;
        }
        if let Ok(mut chunk) = self.producer.write_chunk(n) {
            let (a, b) = chunk.as_mut_slices();
            let (sa, sb) = samples[..n].split_at(a.len());
            a.copy_from_slice(sa);
            b.copy_from_slice(sb);
            chunk.commit_all();
        }
        n
    }

    /// 缓冲里还没播出去的样本数
    pub fn queued(&self) -> usize {
        self.producer.buffer().capacity() - self.producer.slots()
    }
}
