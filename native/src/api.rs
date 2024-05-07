use std::io::Cursor;
use farbe::image::n64::{NativeImage, ImageFormat};

fn map_dart_value_to_image_format(value: u8) -> ImageFormat {
    match value {
        1 => ImageFormat::RGBA32,
        2 => ImageFormat::RGBA16,
        3 => ImageFormat::CI4,
        4 => ImageFormat::CI8,
        5 => ImageFormat::I4,
        6 => ImageFormat::I8,
        7 => ImageFormat::IA4,
        8 => ImageFormat::IA8,
        9 => ImageFormat::IA16,
        _ => panic!("Invalid image format"),
    }
}

pub fn convert_native_to_png(bytes: Vec<u8>, format: u8, width: u32, height: u32) -> Vec<u8> {
    let mut cursor = Cursor::new(bytes);
    let format = map_dart_value_to_image_format(format);
    let image = NativeImage::read(&mut cursor, format, width, height).unwrap();

    let mut output = Vec::new();
    image.as_png(&mut output).unwrap();

    output
}
