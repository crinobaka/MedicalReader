use mupdf::{Document as MuPdfDocument, Error};

use super::renderer::{render_page, RenderedPage};

pub struct Document {
    id: String,
    path: String,
    inner: MuPdfDocument,
}

impl Document {
    pub fn open(id: String, path: String) -> Result<Self, Error> {
        let inner = MuPdfDocument::open(&path)?;

        Ok(Self {
            id,
            path,
            inner,
        })
    }

    pub fn id(&self) -> &str {
        &self.id
    }

    pub fn path(&self) -> &str {
        &self.path
    }

    pub fn page_count(&self) -> Result<u32, Error> {
        self.inner.page_count()
    }

    pub fn render_page(
        &self,
        page_index: u32,
        dpi: u32,
    ) -> Result<RenderedPage, Error> {
        render_page(&self.inner, page_index, dpi)
    }
}