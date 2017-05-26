meta:
  id: dicom_le
  title: Digital Imaging and Communications in Medicine (DICOM) file format
  file-extension: dcm
  license: MIT
  endian: le
doc-ref: http://dicom.nema.org/medical/dicom/current/output/html/part10.html
doc: |
  DICOM (Digital Imaging and Communications in Medicine), AKA NEMA
  PS3, AKA ISO 12052:2006, is a file format and network protocol
  standard for medical imaging purposes. This parser covers file
  format, typically written by various medical equipment, such as
  radiography, computer tomography scans, MRT, ultrasonography, etc.

  DICOM defines two transfer syntaxes: implicit and explicit. This
  top-level parser attempts to autodetect and handle both of them. If
  any problems arise, one can use `file_explicit` and `file_implicit`
  subtypes to force parsing in particular transfer syntax.
seq:
  - id: file_header
    type: t_file_header
  - id: dataset
    type: t_dataset
types:
  file_explicit:
    doc: |
      This type parses DICOM files with explicit transfer syntax.
    seq:
      - id: file_header
        type: t_file_header
      - id: dataset
        type: t_dataset_explicit
    types:
      t_dataset_explicit:
        seq:
          - id: elements
            type: t_dataentry_explicit
            repeat: eos
  file_implicit:
    doc: |
      This type parses DICOM files with implicit transfer syntax.
    seq:
      - id: file_header
        type: t_file_header
      - id: dataset
        type: t_dataset_implicit
    types:
      t_dataset_implicit:
        seq:
          - id: elements
            type: t_dataentry_implicit
            repeat: eos
  t_dataset:
    doc-ref: http://dicom.nema.org/dicom/2013/output/chtml/part05/chapter_7.html
    seq:
      - id: elements1
        type: t_dataentry_implicit
        if: not _io.eof
        repeat: until
        repeat-until: _io.eof or _.is_transfer_syntax_change_explicit
      - id: elements2
        type: t_dataentry_explicit
        repeat: eos
  t_file_header:
    seq:
      - id: preamble
        size: 128
      - id: magic
        contents: 'DICM'
  t_dataentry_implicit:
    seq:
      - id: tag_group
        type: u2
      - id: tag_elem
        type: u2
      - id: header
        type:
          switch-on: entry_implicit
          cases:
            true: t_entry_header_implicit
            false: t_entry_header_explicit
      - id: content
        size: header_content_length
        if: has_content
      - id: elements_1
        type: t_dataentry_implicit
        if: has_elements and not is_definite
        repeat: until
        repeat-until: _.is_closing_tag
      - id: elements_2
        type: t_elements
        if: has_elements and is_definite
        size: header_content_length
    types:
      t_elements:
        seq:
          - id: elements
            type: t_dataentry_implicit
            repeat: eos
    instances:
      entry_implicit:
        value: tag_group != 2 or tag_group == 0xfffe
      is_closing_tag:
        value: (tag_group == 0xfffe) and (tag_elem & 0xff00 == 0xe000) and (tag_elem != 0xe000)
      has_elements:
        value: (tag_group == 0xfffe and tag_elem == 0xe000) or header_is_seq
      has_content:
        value: not has_elements
      is_definite:
        value: header_content_length != 0xffffffff
      p_is_transfer_syntax_change_non_implicit:
        # '1.2.840.10008.1.2.1\0' (Explicit VR Little Endian)
        # See http://www.dicomlibrary.com/dicom/transfer-syntax/
        value: content != [49, 46, 50, 46, 56, 52, 48, 46, 49, 48, 48, 48, 56, 46, 49, 46, 50, 46, 49, 0]
      is_transfer_syntax_change_explicit:
        value: tag_group == 2 and tag_elem == 16 and p_is_transfer_syntax_change_non_implicit
      header_is_seq:
        value: >-
          entry_implicit ?
            header.as<t_entry_header_implicit>.is_seq :
            header.as<t_entry_header_explicit>.is_seq
      header_content_length:
        value: >-
          entry_implicit ?
            header.as<t_entry_header_implicit>.content_length :
            header.as<t_entry_header_explicit>.content_length
  t_dataentry_explicit:
    seq:
      - id: tag_group
        type: u2
      - id: tag_elem
        type: u2
      - id: header
        if: header_is_implicit
        type: t_entry_header_implicit
      - id: header
        if: not header_is_implicit
        type: t_entry_header_explicit
      - id: content
        size: header.content_length
        if: has_content
      - id: elements
        type: t_dataentry_explicit
        if: has_elements and not is_definite
        repeat: until
        repeat-until: _.is_closing_tag
      - id: elements
        type: t_elements
        if: has_elements and is_definite
        size: header.content_length
    types:
      t_elements:
        seq:
          - id: elements
            type: t_dataentry_explicit
            repeat: eos
    instances:
      header_is_implicit:
        value: tag_group == 0xfffe
      is_closing_tag:
        value: tag_group == 0xfffe and tag_elem & 0xff00 == 0xe000 and tag_elem != 0xe000
      has_elements:
        value: (tag_group == 0xfffe and tag_elem == 0xe000) or header.is_seq
      has_content:
        value: not has_elements
      is_definite:
        value: header.content_length != 0xffffffff
  t_entry_header_explicit:
    seq:
      - id: vr
        type: str
        encoding: ASCII
        size: 2
      - id: p_reserved
        type: u2
        if: length_is_long
      - id: p_content_length_u4
        type: u4
        if: length_is_long
      - id: p_content_length_u2
        type: u2
        if: not length_is_long
    instances:
      content_length:
        value: 'length_is_long ? p_content_length_u4 : p_content_length_u2'
      length_is_long:
        value: >
          not (
            vr == 'AE' or
            vr == 'AS' or
            vr == 'AT' or
            vr == 'CS' or
            vr == 'DA' or
            vr == 'DS' or
            vr == 'DT' or
            vr == 'FL' or
            vr == 'FD' or
            vr == 'IS' or
            vr == 'LO' or
            vr == 'PN' or
            vr == 'SH' or
            vr == 'SL' or
            vr == 'SS' or
            vr == 'ST' or
            vr == 'TM' or
            vr == 'UI' or
            vr == 'UL' or
            vr == 'US' or
            vr == 'LT'
          )
      is_seq:
        value: vr == 'SQ'
  t_entry_header_implicit:
    seq:
      - id: content_length
        type: u4
    instances:
      is_seq:
        value: content_length == 0xffffffff
