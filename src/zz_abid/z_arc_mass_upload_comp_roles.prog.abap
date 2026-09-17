*&---------------------------------------------------------------------*
*& Report Z_ARC_MASS_UPLOAD_COMP_ROLES
*&---------------------------------------------------------------------*
*& Description: Mass upload of composite/single role relationships
*&              to custom table ZCOMP_ROLE_HDR.
*&---------------------------------------------------------------------*
PROGRAM z_arc_mass_upload_comp_roles.
TABLES: agr_agrs.

*--------------------------------------------------------------------*
* Selection Screen
*--------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS: s_agr FOR agr_agrs-agr_name. " Composite Role Name
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
  PARAMETERS:
  "p_test RADIOBUTTON GROUP g1 DEFAULT 'X', " Test Run
              p_upd  AS CHECKBOX. "RADIOBUTTON GROUP g1 DEFAULT 'X'.             " Final Run (Update)
SELECTION-SCREEN END OF BLOCK b2.

*--------------------------------------------------------------------*
* Data Declarations
*--------------------------------------------------------------------*
TYPES: BEGIN OF ty_text,
         agr_name TYPE agr_name,
         text     TYPE agr_title,
       END OF ty_text.

TYPES: BEGIN OF ty_existing_keys,
         agr_name  TYPE agr_name,
         child_agr TYPE agr_name,
       END OF ty_existing_keys.

DATA: lt_agr_agrs      TYPE TABLE OF agr_agrs,
      lt_texts         TYPE TABLE OF ty_text,
      lt_owners        TYPE TABLE OF zrecman_owners,
      lt_zcomp_hdr     TYPE TABLE OF zcomp_role_hdr,
      ls_zcomp_hdr     TYPE zcomp_role_hdr,
      lt_all_roles     TYPE TABLE OF agr_name,
      lt_existing_keys TYPE TABLE OF ty_existing_keys. " For duplicate check

*--------------------------------------------------------------------*
* Main Processing
*--------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM get_data.
  PERFORM process_data.
  PERFORM display_alv.

*--------------------------------------------------------------------*
* Form GET_DATA
*--------------------------------------------------------------------*
FORM get_data.
  " 1. Get Composite to Single Role relationships
  SELECT agr_name, child_agr
    FROM agr_agrs
    INTO CORRESPONDING FIELDS OF TABLE @lt_agr_agrs
    WHERE agr_name IN @s_agr.

  IF sy-subrc <> 0.
    MESSAGE 'No composite roles found for the given selection.' TYPE 'S' DISPLAY LIKE 'E'.
    LEAVE LIST-PROCESSING.
  ENDIF.

  " 2. Collect all unique role names
  LOOP AT lt_agr_agrs INTO DATA(ls_rel).
    APPEND ls_rel-agr_name  TO lt_all_roles.
    APPEND ls_rel-child_agr TO lt_all_roles.
  ENDLOOP.
  SORT lt_all_roles.
  DELETE ADJACENT DUPLICATES FROM lt_all_roles.

  " 3. Get Role Descriptions
  IF lt_all_roles IS NOT INITIAL.
    SELECT agr_name, text
      FROM agr_texts
      INTO TABLE @lt_texts
      FOR ALL ENTRIES IN @lt_all_roles
      WHERE agr_name = @lt_all_roles-table_line
        AND spras    = @sy-langu
        AND line     = '00000'.
  ENDIF.

  " 4. Get Mapping Configuration for Owner Group
  SELECT * FROM zrecman_owners INTO TABLE @lt_owners.

  " 5. Check Database for Existing Records to exclude them
  IF lt_agr_agrs IS NOT INITIAL.
    SELECT agr_name, child_agr
      FROM zcomp_role_hdr
      INTO TABLE @lt_existing_keys
      FOR ALL ENTRIES IN @lt_agr_agrs
      WHERE agr_name  = @lt_agr_agrs-agr_name
        AND child_agr = @lt_agr_agrs-child_agr.

    " Sort is mandatory for the BINARY SEARCH later
    SORT lt_existing_keys BY agr_name child_agr.
  ENDIF.
ENDFORM.

*--------------------------------------------------------------------*
* Form PROCESS_DATA
*--------------------------------------------------------------------*
FORM process_data.
  DATA: lv_continue   TYPE abap_bool,
        lv_tzone      TYPE tzone,
        lv_ts         TYPE timestamp,
        lv_date       TYPE d,
        lv_time       TYPE t,
        lv_created_at TYPE char14.


  lv_tzone = cl_abap_context_info=>get_user_time_zone( ).

  GET TIME STAMP FIELD lv_ts.                       " UTC timestamp
  CONVERT TIME STAMP lv_ts TIME ZONE 'UTC'
          INTO DATE lv_date TIME lv_time.           " split to date/time
  lv_created_at = |{ lv_date }{ lv_time }|.         " 'YYYYMMDDHHMMSS'


  LOOP AT lt_agr_agrs INTO DATA(ls_agr).

    " ---> NEW EXCLUSION LOGIC: Skip if record already exists in database
    READ TABLE lt_existing_keys TRANSPORTING NO FIELDS
         WITH KEY agr_name  = ls_agr-agr_name
                  child_agr = ls_agr-child_agr
         BINARY SEARCH.

    IF sy-subrc = 0.
      CONTINUE. " Record exists, skip to the next loop iteration
    ENDIF.
    " <--- END NEW EXCLUSION LOGIC

    CLEAR ls_zcomp_hdr.

    " 1. Set Client & Mapping
    ls_zcomp_hdr-mandt     = sy-mandt.
    ls_zcomp_hdr-agr_name  = ls_agr-agr_name.
    ls_zcomp_hdr-child_agr = ls_agr-child_agr.

    " 2. Get Descriptions
    READ TABLE lt_texts INTO DATA(ls_comp_text) WITH KEY agr_name = ls_agr-agr_name.
    IF sy-subrc = 0. ls_zcomp_hdr-agr_name_descr = ls_comp_text-text. ENDIF.

    READ TABLE lt_texts INTO DATA(ls_child_text) WITH KEY agr_name = ls_agr-child_agr.
    IF sy-subrc = 0. ls_zcomp_hdr-child_agr_descr = ls_child_text-text. ENDIF.

    " 3. Determine OWNER_GROUP
    LOOP AT lt_owners INTO DATA(ls_owner) WHERE owner_group IS NOT INITIAL.
      IF ls_zcomp_hdr-agr_name CS ls_owner-owner_group.
        ls_zcomp_hdr-owner_group = ls_owner-owner_group.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF ls_zcomp_hdr-owner_group IS INITIAL.
      LOOP AT lt_owners INTO ls_owner WHERE identicator IS NOT INITIAL.
        IF ls_zcomp_hdr-agr_name_descr CS ls_owner-identicator.
          ls_zcomp_hdr-owner_group = ls_owner-owner_group.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " 4. Set Default Fields
    ls_zcomp_hdr-create_flag        = abap_true.
*    ls_zcomp_hdr-created_at         = sy-datum.
    ls_zcomp_hdr-created_at         = lv_created_at.
    ls_zcomp_hdr-wf_approval_status = 'PENDING'.
    CLEAR ls_zcomp_hdr-changed_at.

    APPEND ls_zcomp_hdr TO lt_zcomp_hdr.
  ENDLOOP.

  " Inform user if everything was already in the database
  IF lt_zcomp_hdr IS INITIAL.
    MESSAGE 'All selected composite roles already exist in the custom table. No new data to process.' TYPE 'S' DISPLAY LIKE 'W'.
    LEAVE LIST-PROCESSING.
  ENDIF.

  " Handle Final Run Database Update with Pop-Up
*  IF p_upd = abap_true.
*    PERFORM confirm_save CHANGING lv_continue.
*
*    IF lv_continue = abap_true.
*      MODIFY zcomp_role_hdr FROM TABLE lt_zcomp_hdr.
*      COMMIT WORK AND WAIT.
*      MESSAGE |Final Run: { sy-dbcnt } new records inserted successfully.| TYPE 'S'.
*    ELSE.
*      MESSAGE 'Save cancelled by user.' TYPE 'S' DISPLAY LIKE 'W'.
*    ENDIF.
*  ELSEIF p_test = abap_true.
*    MESSAGE 'Test Run: Review data. Highlight specific rows and click Save.' TYPE 'S'.
*  ENDIF.

ENDFORM.

*--------------------------------------------------------------------*
* Form DISPLAY_ALV
*--------------------------------------------------------------------*
FORM display_alv.
  DATA: lt_fcat   TYPE lvc_t_fcat,
        ls_layout TYPE lvc_s_layo,
        lt_sort   TYPE lvc_t_sort,
        ls_sort   TYPE lvc_s_sort.

  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name       = 'ZCOMP_ROLE_HDR'
      i_bypassing_buffer     = abap_true
    CHANGING
      ct_fieldcat            = lt_fcat
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2
      OTHERS                 = 3.

  LOOP AT lt_fcat ASSIGNING FIELD-SYMBOL(<fs_fcat>).
    IF <fs_fcat>-fieldname = 'OWNER_GROUP'.
      <fs_fcat>-edit = abap_true.
    ENDIF.
  ENDLOOP.

  ls_layout-cwidth_opt = abap_true.
  ls_layout-zebra      = abap_true.
  ls_layout-sel_mode   = 'D'.

  ls_sort-spos      = 1.
  ls_sort-fieldname = 'AGR_NAME'.
  ls_sort-up        = abap_true.
  APPEND ls_sort TO lt_sort.

  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
    EXPORTING
      i_callback_program      = sy-repid
      i_callback_top_of_page  = 'TOP_OF_PAGE'
      i_callback_user_command = 'USER_COMMAND'
      is_layout_lvc           = ls_layout
      it_fieldcat_lvc         = lt_fcat
      it_sort_lvc             = lt_sort
    TABLES
      t_outtab                = lt_zcomp_hdr
    EXCEPTIONS
      program_error           = 1
      OTHERS                  = 2.
ENDFORM.

*--------------------------------------------------------------------*
* Form TOP_OF_PAGE
*--------------------------------------------------------------------*
FORM top_of_page.
  DATA: lt_header TYPE slis_t_listheader,
        ls_header TYPE slis_listheader,
        lv_lines  TYPE i,
        lv_date   TYPE char10,
        lv_time   TYPE char8,
        lv_text   TYPE char50.

  lv_lines = lines( lt_zcomp_hdr ).
  WRITE sy-datum TO lv_date.
  WRITE sy-uzeit TO lv_time.

  ls_header-typ  = 'H'.
  ls_header-info = 'Mass Upload: New Composite Role Processing'.
  APPEND ls_header TO lt_header.

  ls_header-typ  = 'S'.
  ls_header-key  = 'New Records:'.
  WRITE lv_lines TO lv_text LEFT-JUSTIFIED.
  ls_header-info = lv_text.
  APPEND ls_header TO lt_header.

  ls_header-typ  = 'S'.
  ls_header-key  = 'System Date:'.
  ls_header-info = lv_date.
  APPEND ls_header TO lt_header.

  ls_header-typ  = 'S'.
  ls_header-key  = 'System Time:'.
  ls_header-info = lv_time.
  APPEND ls_header TO lt_header.

  CALL FUNCTION 'REUSE_ALV_COMMENTARY_WRITE'
    EXPORTING
      it_list_commentary = lt_header.
ENDFORM.

*--------------------------------------------------------------------*
* Form USER_COMMAND
*--------------------------------------------------------------------*
FORM user_command USING r_ucomm     LIKE sy-ucomm
                        rs_selfield TYPE slis_selfield.

  DATA: lo_grid      TYPE REF TO cl_gui_alv_grid,
        lt_row_no    TYPE lvc_t_roid,
        ls_row_no    TYPE lvc_s_roid,
        lt_save_data TYPE TABLE OF zcomp_role_hdr,
        lv_continue  TYPE abap_bool.

  CALL FUNCTION 'GET_GLOBALS_FROM_SLVC_FULLSCR'
    IMPORTING
      e_grid = lo_grid.

  IF lo_grid IS BOUND.
    lo_grid->check_changed_data( ).
    lo_grid->get_selected_rows( IMPORTING et_row_no = lt_row_no ).
  ENDIF.

  CASE r_ucomm.
    WHEN '&DATA_SAVE'.
      IF lt_row_no IS INITIAL.
        MESSAGE 'Please select at least one row from the grid to save.' TYPE 'I' DISPLAY LIKE 'W'.
        RETURN.
      ENDIF.

      IF p_upd IS NOT INITIAL.
        LOOP AT lt_row_no INTO ls_row_no.
          READ TABLE lt_zcomp_hdr INTO DATA(ls_row_data) INDEX ls_row_no-row_id.
          IF sy-subrc = 0.
            APPEND ls_row_data TO lt_save_data.
          ENDIF.
        ENDLOOP.

        IF lt_save_data IS NOT INITIAL.
          PERFORM confirm_save CHANGING lv_continue.

          IF lv_continue = abap_true.
            MODIFY zcomp_role_hdr FROM TABLE lt_save_data.
            COMMIT WORK AND WAIT.
            MESSAGE |Successfully saved { lines( lt_save_data ) } selected records.| TYPE 'S'.

            REFRESH lt_row_no.
            lo_grid->set_selected_rows( it_row_no = lt_row_no ).
          ELSE.
            MESSAGE 'Save cancelled by user.' TYPE 'S'.
          ENDIF.
        ENDIF.
      ELSE.
        MESSAGE 'Tick on Final Run for saving' TYPE 'S'.

      ENDIF.

  ENDCASE.
ENDFORM.

*--------------------------------------------------------------------*
* Form CONFIRM_SAVE
*--------------------------------------------------------------------*
FORM confirm_save CHANGING cv_continue TYPE abap_bool.
  DATA: lv_answer TYPE char1.

  cv_continue = abap_false.

  IF sy-batch = abap_true.
    cv_continue = abap_true.
    RETURN.
  ENDIF.

  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = 'Confirm Data Save'
      text_question         = 'Are you sure you want to write these new records to the database?'
      text_button_1         = 'Yes'
      icon_button_1         = 'ICON_SYSTEM_SAVE'
      text_button_2         = 'No'
      icon_button_2         = 'ICON_CANCEL'
      default_button        = '2'
      display_cancel_button = abap_false
    IMPORTING
      answer                = lv_answer
    EXCEPTIONS
      text_not_found        = 1
      OTHERS                = 2.

  IF sy-subrc = 0 AND lv_answer = '1'.
    cv_continue = abap_true.
  ENDIF.
ENDFORM.
