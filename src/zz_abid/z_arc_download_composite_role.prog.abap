*&---------------------------------------------------------------------*
*& Report Z_ARC_DOWNLOAD_COMPOSITE_ROLE
*&---------------------------------------------------------------------*
*& Purpose: Download a PFCG role to a local file using OO-ABAP.
*&---------------------------------------------------------------------*
REPORT z_arc_download_composite_role.

*----------------------------------------------------------------------*
* SELECTION SCREEN
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  PARAMETERS: p_role TYPE agr_name OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b1.

PERFORM download_agr USING p_role.

FORM download_agr USING role.
  DATA: filename TYPE file_table-filename.
  DATA: default_path TYPE file_table-filename.
  CONCATENATE role '.SAP' INTO default_path.

  CALL FUNCTION 'PRGN_CALL_INFO_TEXT_POPUP'
    EXPORTING
      info_text       = 'PROFGEN_INFO_TEXT_21C'
    EXCEPTIONS
      action_canceled = 1
      OTHERS          = 2.

  IF sy-subrc <> 0.
    MESSAGE s232(s#).
    EXIT.
  ENDIF.
  DATA:
    l_with_encoding TYPE char01     VALUE  'X',
    l_file_encoding TYPE abap_encod.

  CALL FUNCTION 'NAVIGATION_FILENAME_HELP'
    EXPORTING
      default_path_long      = default_path
      mode                   = 'S'
      with_encoding          = l_with_encoding
    IMPORTING
      selected_filename_long = filename
    CHANGING
      file_encoding          = l_file_encoding.
  IF filename = space.
    MESSAGE s232(s#).
    EXIT.
  ENDIF.
  CALL FUNCTION 'PRGN_DOWNLOAD_AGR'
    EXPORTING
      filename_for_agr              = filename
      filetype_for_agr              = 'ASC'
      activity_group                = role
      with_user_assignment          = ' '
      file_encoding                 = l_file_encoding
    EXCEPTIONS
      activity_group_does_not_exist = 1
      file_write_error              = 2
      file_open_error               = 3
      file_general_error            = 4
      not_authorized                = 5
      OTHERS                        = 6.
  CASE sy-subrc.
    WHEN 1.
      MESSAGE s234(s#) WITH role.
    WHEN 2.
      MESSAGE s383(s#) WITH filename.
    WHEN 3.
      MESSAGE s382(s#) WITH filename.
    WHEN 4.
      MESSAGE s384(s#) WITH filename.
    WHEN 5.
*     Message schon im Baustein
  ENDCASE.
ENDFORM.
