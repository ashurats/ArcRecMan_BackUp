"Name: \PR:SAPLPRGN_TREE\FO:UCOMM_DOWNLOAD_AGR\SE:BEGIN\EI
ENHANCEMENT 0 ZRECMAN_AGR_DOWNLOAD_ROLES.

DATA: lv_coll_role   TYPE char01,
      ls_data        TYPE zrecman_dl_logs,
      lv_ts          TYPE timestamp,
      lv_d           TYPE d,
      lv_t           TYPE t,
      lv_now         TYPE char32,
      lv_role_status TYPE zcomp_role_hdr-wf_approval_status,
      lv_owner_group TYPE zcomp_role_hdr-owner_group.

*-> Get Timestamp
GET TIME STAMP FIELD lv_ts.
CONVERT TIME STAMP lv_ts TIME ZONE 'UTC' INTO DATE lv_d TIME lv_t.
lv_now = |{ lv_d }{ lv_t }|.

*-> Check for Composite role (Prüfung auf Sammelrolle)
CALL FUNCTION 'PRGN_GET_COLLECTIVE_AGR_FLAG'
  EXPORTING
    activity_group      = p_agr_name_neu
  IMPORTING
    collective_agr_flag = lv_coll_role
  EXCEPTIONS
    agr_does_not_exist  = 1
    flag_not_available  = 2
    OTHERS              = 3.

IF lv_coll_role = ''.  " Single role

  SELECT SINGLE wf_approval_status
    INTO ( @lv_role_status )
    FROM zcomp_role_hdr
    WHERE child_agr = @p_agr_name_neu.

ELSEIF lv_coll_role = '' or lv_coll_role = 'X'.   " Composite role & Single role

  SELECT SINGLE owner_group
    INTO ( @lv_owner_group )
    FROM zcomp_role_hdr
    WHERE agr_name = @p_agr_name_neu.

ENDIF.

ls_data = VALUE #( agr_name           = p_agr_name_neu
                   role_type          = COND #( WHEN lv_coll_role = 'X'
                                        THEN 'Composite Role'
                                        ELSE 'Single Role' )
                   owner_group        = lv_owner_group
                   system_id          = sy-sysid
                   wf_approval_status = COND #( WHEN lv_coll_role = ''
                                        THEN lv_role_status
                                        ELSE 'PENDING' )
                   download_date      = lv_now
                   downloaded_by      = sy-uname ).

MODIFY zrecman_dl_logs FROM ls_data.
COMMIT WORK.

ENDENHANCEMENT.
