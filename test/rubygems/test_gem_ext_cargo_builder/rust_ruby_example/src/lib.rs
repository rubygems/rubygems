use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int, c_long, c_ulong, c_void};

#[repr(C)]
#[derive(Copy, Clone, Debug, PartialEq)]
pub struct Value {
  pub value: c_ulong,
}

extern "C" {
  pub fn rb_define_module(name: *const c_char) -> Value;
  pub fn rb_define_module_function(
    klass: Value,
    name: *const c_char,
    callback: *const c_void,
    argc: c_int,
  );
  pub fn rb_string_value_cstr(str: *const Value) -> *const c_char;
  pub fn rb_utf8_str_new(str: *const c_char, len: c_long) -> Value;
}

unsafe fn cstr_to_string(str: *const c_char) -> String {
  CStr::from_ptr(str).to_string_lossy().into_owned()
}

#[no_mangle]
extern "C" fn pub_reverse(_klass: Value, input: Value) -> Value {
  let ruby_string = unsafe { cstr_to_string(rb_string_value_cstr(&input)) };
  let reversed = ruby_string.to_string().chars().rev().collect::<String>();
  let reversed_cstring = CString::new(reversed).unwrap();
  let size = ruby_string.len() as c_long;

  unsafe { rb_utf8_str_new(reversed_cstring.as_ptr(), size) }
}

#[allow(non_snake_case)]
#[no_mangle]
pub extern "C" fn Init_rust_ruby_example() {
  let name = CString::new("RustRubyExample").unwrap();
  let function_name = CString::new("reverse").unwrap();
  let callback = pub_reverse as *const fn() as *const c_void;
  let klass = unsafe { rb_define_module(name.as_ptr()) };

  unsafe { rb_define_module_function(klass, function_name.as_ptr(), callback, 1) }
}
