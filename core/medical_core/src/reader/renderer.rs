use mupdf::{Colorspace, Document, Error, Matrix};

pub struct RenderedPage {
    pub width: u32,
    pub height: u32,
    pub stride: usize,
    pub components: u8,
    pub data: Vec<u8>,
}

pub fn render_page(
    document: &Document,
    page_index: u32,
    dpi: u32,
) -> Result<RenderedPage, Error> {
    let dpi = if dpi == 0 { 72 } else { dpi };

    let page_index = page_index as i32;

    let page = document.load_page(page_index)?;

    let scale = dpi as f32 / 72.0;

    let matrix = Matrix::new_scale(scale, scale);

    let colorspace = Colorspace::device_rgb();

    let pixmap = page.to_pixmap(
        &matrix,
        &colorspace,
        false,
        true,
    )?;

    let width = pixmap.width();
    let height = pixmap.height();
    let stride = pixmap.stride() as usize;
    let components = pixmap.n();
    let data = pixmap.samples().to_vec();

    Ok(RenderedPage {
        width,
        height,
        stride,
        components,
        data,
    })
}