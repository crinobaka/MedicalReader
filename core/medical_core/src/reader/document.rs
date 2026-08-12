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
        let page_count = self.inner.page_count()?;

        if page_count < 0 {
            return Err(Error::Generic(
                "MuPDF returned a negative page count".to_string(),
            ));
        }

        Ok(page_count as u32)
    }

    pub fn render_page(
        &self,
        page_index: u32,
        dpi: u32,
    ) -> Result<RenderedPage, Error> {
        render_page(&self.inner, page_index, dpi)
    }
}