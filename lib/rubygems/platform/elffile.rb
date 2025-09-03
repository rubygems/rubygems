# frozen_string_literal: true

##
# Minimal ELF file parser for Ruby platform detection, inspired by Python's packaging._elffile
# This module implements just enough ELF parsing to extract the dynamic interpreter path
# needed for musl/glibc detection.
#
# Based on Python's packaging._elffile
# https://github.com/pypa/packaging/blob/0055d4b56ae868bbcc7825c9ad68f49cdcb9f8b9/src/packaging/_elffile.py

module Gem::Platform::ELFFile
  # ELF file format constants
  EI_MAG0 = 0
  EI_MAG1 = 1
  EI_MAG2 = 2
  EI_MAG3 = 3
  EI_CLASS = 4
  EI_DATA = 5

  ELFMAG0 = 0x7f
  ELFMAG1 = 0x45  # 'E'
  ELFMAG2 = 0x4c  # 'L'
  ELFMAG3 = 0x46  # 'F'

  ELFCLASS32 = 1
  ELFCLASS64 = 2

  ELFDATA2LSB = 1  # Little endian
  ELFDATA2MSB = 2  # Big endian

  PT_INTERP = 3    # Program header type for interpreter

  # Minimal ELF file reader to extract interpreter path
  class Reader
    attr_reader :interpreter

    def initialize(file_path)
      @file_path = file_path
      @interpreter = nil
      @file_size = File.size(file_path)

      File.open(file_path, "rb") do |file|
        parse_elf_header(file)
        extract_interpreter(file) if valid_elf?
      end
    end

    private

    def parse_elf_header(file)
      # Read ELF identification (16 bytes)
      @e_ident = file.read(16)&.unpack("C*")
      return unless @e_ident&.size == 16

      # Verify ELF magic number
      return unless @e_ident[EI_MAG0] == ELFMAG0 &&
                    @e_ident[EI_MAG1] == ELFMAG1 &&
                    @e_ident[EI_MAG2] == ELFMAG2 &&
                    @e_ident[EI_MAG3] == ELFMAG3

      @ei_class = @e_ident[EI_CLASS]
      @ei_data = @e_ident[EI_DATA]

      # Determine if 32-bit or 64-bit and endianness
      @is_64bit = @ei_class == ELFCLASS64
      @is_little_endian = @ei_data == ELFDATA2LSB

      # Read rest of ELF header based on architecture
      read_elf_header_fields(file)
    end

    def read_elf_header_fields(file)
      if @is_64bit
        # 64-bit ELF header (remaining fields after e_ident)
        header_data = file.read(48)
        return unless header_data&.size == 48

        # ELF64 header: e_type(2) e_machine(2) e_version(4) e_entry(8) e_phoff(8) e_shoff(8) e_flags(4) e_ehsize(2) e_phentsize(2) e_phnum(2) e_shentsize(2) e_shnum(2) e_shstrndx(2)
        if @is_little_endian
          @e_type, @e_machine, @e_version, @e_entry, @e_phoff, @e_shoff, @e_flags, @e_ehsize, @e_phentsize, @e_phnum, @e_shentsize, @e_shnum, @e_shstrndx = header_data.unpack("vvVQ<Q<Q<Vvvvvvv")
        else
          @e_type, @e_machine, @e_version, @e_entry, @e_phoff, @e_shoff, @e_flags, @e_ehsize, @e_phentsize, @e_phnum, @e_shentsize, @e_shnum, @e_shstrndx = header_data.unpack("nnNQ>Q>Q>Nnnnnnn")
        end
      else
        # 32-bit ELF header
        header_data = file.read(36)
        return unless header_data&.size == 36

        # ELF32 header: e_type(2) e_machine(2) e_version(4) e_entry(4) e_phoff(4) e_shoff(4) e_flags(4) e_ehsize(2) e_phentsize(2) e_phnum(2) e_shentsize(2) e_shnum(2) e_shstrndx(2)
        if @is_little_endian
          @e_type, @e_machine, @e_version, @e_entry, @e_phoff, @e_shoff, @e_flags, @e_ehsize, @e_phentsize, @e_phnum, @e_shentsize, @e_shnum, @e_shstrndx = header_data.unpack("vvVVVVVvvvvvv")
        else
          @e_type, @e_machine, @e_version, @e_entry, @e_phoff, @e_shoff, @e_flags, @e_ehsize, @e_phentsize, @e_phnum, @e_shentsize, @e_shnum, @e_shstrndx = header_data.unpack("nnNNNNNnnnnnnn")
        end
      end
    end

    def extract_interpreter(file)
      return unless @e_phoff && @e_phnum && @e_phentsize

      # Read program headers to find PT_INTERP
      @e_phnum.times do |idx|
        ph_offset = @e_phoff + @e_phentsize * idx

        file.seek(ph_offset)

        if @is_64bit
          # 64-bit program header: p_type(4) p_flags(4) p_offset(8) p_vaddr(8) p_paddr(8) p_filesz(8) p_memsz(8) p_align(8)
          ph_data = file.read(56)
          next unless ph_data&.size == 56

          if @is_little_endian
            p_type, _p_flags, p_offset, _p_vaddr, _p_paddr, p_filesz, _p_memsz, _p_align = ph_data.unpack("VVQ<Q<Q<Q<Q<Q<")
          else
            p_type, _p_flags, p_offset, _p_vaddr, _p_paddr, p_filesz, _p_memsz, _p_align = ph_data.unpack("NNQ>Q>Q>Q>Q>Q>")
          end
        else
          # 32-bit program header: p_type(4) p_offset(4) p_vaddr(4) p_paddr(4) p_filesz(4) p_memsz(4) p_flags(4) p_align(4)
          ph_data = file.read(32)
          next unless ph_data&.size == 32

          if @is_little_endian
            p_type, p_offset, _p_vaddr, _p_paddr, p_filesz, _p_memsz, _p_flags, _p_align = ph_data.unpack("VVVVVVVV")
          else
            p_type, p_offset, _p_vaddr, _p_paddr, p_filesz, _p_memsz, _p_flags, _p_align = ph_data.unpack("NNNNNNNN")
          end
        end

        next unless p_type == PT_INTERP && p_filesz > 0 && p_offset < @file_size
        # Found interpreter segment, read the path
        file.seek(p_offset)
        interp_data = file.read([p_filesz, 256].min) # Limit read size
        @interpreter = interp_data&.unpack("Z*")&.first # Null-terminated string
        break
      end
    end

    def valid_elf?
      return false unless @e_ident &&
                          @e_ident[EI_MAG0] == ELFMAG0 &&
                          @e_ident[EI_MAG1] == ELFMAG1 &&
                          @e_ident[EI_MAG2] == ELFMAG2 &&
                          @e_ident[EI_MAG3] == ELFMAG3 &&
                          (@ei_class == ELFCLASS32 || @ei_class == ELFCLASS64)

      # Check if we have enough data for a complete ELF header
      min_size = @is_64bit ? 64 : 52 # e_ident(16) + header(48 for 64-bit, 36 for 32-bit)
      @file_size >= min_size
    end
  end

  module_function

  # Extract interpreter path from ELF executable
  # Based on Python's packaging._elffile.ELFFile
  # https://github.com/pypa/packaging/blob/0055d4b56ae868bbcc7825c9ad68f49cdcb9f8b9/src/packaging/_elffile.py#L44-L74
  def interpreter(file_path)
    reader = Reader.new(file_path)
    reader.interpreter
  rescue Errno::ENOENT
    nil
  end
end
