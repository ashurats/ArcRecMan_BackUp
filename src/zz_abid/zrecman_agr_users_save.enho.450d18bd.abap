"Name: \PR:SAPLPRGN_TREE\FO:AGR_SAVE_TO_DATABASE_USERS\SE:END\EI
ENHANCEMENT 0 ZRECMAN_AGR_USERS_SAVE.
  DATA: lt_zcomp_role_users TYPE TABLE OF zcomp_role_users WITH HEADER LINE,
        lv_email            TYPE adr6-smtp_addr,
        lv_addrnum          TYPE adr6-addrnumber.
  DATA: lv_ts         TYPE timestamp,
        lv_date       TYPE d,
        lv_time       TYPE t,
        lv_created_at TYPE char14,
        lv_changed_at TYPE char14,
        lv_ucomm      TYPE sy-ucomm.

  DATA: lv_coll_role TYPE char01.


  GET PARAMETER ID 'ZUC' FIELD lv_ucomm.


*  CALL FUNCTION 'PRGN_GET_COLLECTIVE_AGR_FLAG'
*    EXPORTING
*      activity_group      = p_agr_name
*    IMPORTING
*      collective_agr_flag = lv_coll_role
*    EXCEPTIONS
*      agr_does_not_exist  = 1
*      flag_not_available  = 2
*      OTHERS              = 3.
*-> Check for Collective role (Prüfung auf Sammelrolle)
*  IF lv_coll_role EQ abap_true.
    LOOP AT lt_asgm_new ASSIGNING FIELD-SYMBOL(<fs_asgm_new>).
      lt_zcomp_role_users-mandt    = sy-mandt.
      lt_zcomp_role_users-agr_name = <fs_asgm_new>-agr_name.
      lt_zcomp_role_users-username = <fs_asgm_new>-uname.

      SELECT SINGLE u~addrnumber, a~smtp_addr
               INTO (@lv_addrnum, @lv_email)
               FROM usr21 AS u
         INNER JOIN adr6 AS a
                 ON u~addrnumber = a~addrnumber
                AND u~persnumber = a~persnumber
              WHERE u~bname = @<fs_asgm_new>-uname.

      lt_zcomp_role_users-addrnumber = lv_addrnum.
      lt_zcomp_role_users-email      = lv_email.

      SELECT SINGLE created_at INTO lv_created_at FROM zcomp_role_users
        WHERE agr_name = agr_name_neu.

      IF sy-subrc IS NOT INITIAL.
        GET TIME STAMP FIELD lv_ts.                       " UTC timestamp
        CONVERT TIME STAMP lv_ts TIME ZONE 'UTC'
                INTO DATE lv_date TIME lv_time.           " split to date/time
        lv_created_at = |{ lv_date }{ lv_time }|.         " 'YYYYMMDDHHMMSS'
      ENDIF.

      IF lv_ucomm EQ 'SANLE'. "Creating composite role
        lt_zcomp_role_users-created_at = lv_created_at.
      ELSEIF lv_ucomm EQ 'AEND'.   "Changing role
        CONVERT TIME STAMP lv_ts TIME ZONE 'UTC'
                   INTO DATE lv_date TIME lv_time.           " split to date/time
        lv_changed_at = |{ lv_date }{ lv_time }|.         " 'YYYYMMDDHHMMSS'
        lt_zcomp_role_users-changed_at = lv_changed_at.
      ENDIF.

      APPEND lt_zcomp_role_users.
      CLEAR: lt_zcomp_role_users,
             lv_addrnum,
             lv_email,
             lv_created_at,
             lv_changed_at.
    ENDLOOP.
    MODIFY zcomp_role_users FROM TABLE lt_zcomp_role_users.
*  ENDIF.

ENDENHANCEMENT.
