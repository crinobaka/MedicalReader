use std::os::raw::c_void;

#[repr(C)]
pub struct MedicalCorePage {
    pub width: u32,
    pub height: u32,
    pub stride: u32,
    pub components: u8,
    pub data: *mut u8,
    pub data_len: usize,
}

impl MedicalCorePage {
    pub fn from_data(
        width: u32,
        height: u32,
        stride: usize,
        components: u8,
        data: Vec<u8>,
    ) -> *mut MedicalCorePage {
        let data_len = data.len();

        let data = data.into_boxed_slice();

        let data_ptr = Box::into_raw(data) as *mut u8;

        let page = Box::new(MedicalCorePage {
            width,
            height,
            stride: stride as u32,
            components,
            data: data_ptr,
            data_len,
        });

        Box::into_raw(page)
    }
}

#[repr(C)]
pub struct MedicalCoreHandle {
    pub document: *mut c_void,
}