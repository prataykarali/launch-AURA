use anyhow::{bail, Result};
use candle_core::{Device, Tensor, DType};
use std::io::{Read, Write, BufReader, BufWriter};
use std::fs::File;

pub fn save_cache(cache: &[(Option<(Tensor, Tensor)>, Option<Tensor>)], path: &str) -> Result<()> {
    let mut w = BufWriter::new(File::create(path)?);
    w.write_all(&(cache.len() as u32).to_le_bytes())?;
    for (attn, conv) in cache {
        match attn {
            Some((k, v)) => { w.write_all(&[0u8])?; write_tensor(&mut w, k)?; write_tensor(&mut w, v)?; }
            None => match conv {
                Some(c) => { w.write_all(&[1u8])?; write_tensor(&mut w, c)?; }
                None    => { w.write_all(&[2u8])?; }
            }
        }
    }
    w.flush()?;
    Ok(())
}

pub fn load_cache(path: &str, device: &Device) -> Result<Vec<(Option<(Tensor, Tensor)>, Option<Tensor>)>> {
    let mut r = BufReader::new(File::open(path)?);
    let mut b4 = [0u8; 4];
    r.read_exact(&mut b4)?;
    let n = u32::from_le_bytes(b4) as usize;
    let mut cache = Vec::with_capacity(n);
    for _ in 0..n {
        let mut kind = [0u8; 1];
        r.read_exact(&mut kind)?;
        match kind[0] {
            0 => { let k = read_tensor(&mut r, device)?; let v = read_tensor(&mut r, device)?; cache.push((Some((k, v)), None)); }
            1 => { let c = read_tensor(&mut r, device)?; cache.push((None, Some(c))); }
            2 => { cache.push((None, None)); }
            x => bail!("unknown kind: {x}"),
        }
    }
    Ok(cache)
}

fn write_tensor<W: Write>(w: &mut W, t: &Tensor) -> Result<()> {
    let t = t.to_dtype(DType::F32)?;
    let shape = t.shape().dims().to_vec();
    w.write_all(&(shape.len() as u32).to_le_bytes())?;
    for &d in &shape { w.write_all(&(d as u64).to_le_bytes())?; }
    for f in t.flatten_all()?.to_vec1::<f32>()? { w.write_all(&f.to_le_bytes())?; }
    Ok(())
}

fn read_tensor<R: Read>(r: &mut R, device: &Device) -> Result<Tensor> {
    let mut b4 = [0u8; 4];
    r.read_exact(&mut b4)?;
    let ndim = u32::from_le_bytes(b4) as usize;
    let mut shape = vec![0usize; ndim];
    let mut b8 = [0u8; 8];
    for d in shape.iter_mut() { r.read_exact(&mut b8)?; *d = u64::from_le_bytes(b8) as usize; }
    let n: usize = shape.iter().product();
    let mut bytes = vec![0u8; n * 4];
    r.read_exact(&mut bytes)?;
    let data: Vec<f32> = bytes.chunks_exact(4).map(|c| f32::from_le_bytes([c[0],c[1],c[2],c[3]])).collect();
    Ok(Tensor::from_vec(data, shape.as_slice(), device)?)
}
