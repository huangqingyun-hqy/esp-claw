set(EDGE_AGENT_PROJECT_LOG_PREFIX "[edge_agent]")
set(EDGE_AGENT_FLASH_SIZE "")
set(EDGE_AGENT_BOARD_MANAGER_DEFAULTS "${CMAKE_SOURCE_DIR}/components/gen_bmgr_codes/board_manager.defaults")
if(EXISTS "${EDGE_AGENT_BOARD_MANAGER_DEFAULTS}")
    file(STRINGS "${EDGE_AGENT_BOARD_MANAGER_DEFAULTS}" _flash_line REGEX "^CONFIG_ESPTOOLPY_FLASHSIZE_(4|8|16|32)MB=y$")
    if(_flash_line)
        list(GET _flash_line 0 _flash_line)
        string(REGEX REPLACE "^CONFIG_ESPTOOLPY_FLASHSIZE_((4|8|16|32)MB)=y$" "\\1" EDGE_AGENT_FLASH_SIZE "${_flash_line}")
    endif()
    # Allow a board to override the partition table via its sdkconfig.defaults.board.
    # The custom file must exist relative to the project source dir; otherwise fall
    # back to the auto-selected partitions_<size>.csv.
    file(STRINGS "${EDGE_AGENT_BOARD_MANAGER_DEFAULTS}" _board_part_line REGEX "^CONFIG_PARTITION_TABLE_CUSTOM_FILENAME=\".+\"$")
    if(_board_part_line)
        list(GET _board_part_line 0 _board_part_line)
        string(REGEX REPLACE "^CONFIG_PARTITION_TABLE_CUSTOM_FILENAME=\"([^\"]+)\"$" "\\1" _board_part_name "${_board_part_line}")
        if(EXISTS "${CMAKE_SOURCE_DIR}/${_board_part_name}")
            set(EDGE_AGENT_PARTITION_FILENAME "${_board_part_name}")
            message(STATUS "${EDGE_AGENT_PROJECT_LOG_PREFIX} Board overrides partition table: ${_board_part_name}")
        endif()
    endif()
endif()

if(EDGE_AGENT_FLASH_SIZE)
    if(EXISTS "${CMAKE_SOURCE_DIR}/sdkconfig")
        file(READ "${CMAKE_SOURCE_DIR}/sdkconfig" EDGE_AGENT_SDKCONFIG_CONTENT)
        # Normalize CRLF to LF first: on Windows sdkconfig uses CRLF and the
        # line-strip regexes below would never match otherwise.
        string(REPLACE "\r" "" EDGE_AGENT_SDKCONFIG_CONTENT "${EDGE_AGENT_SDKCONFIG_CONTENT}")
        string(REGEX REPLACE "(^|\\n)CONFIG_PARTITION_TABLE_CUSTOM_FILENAME=\"[^\\n]*\"\\n" "\\1" EDGE_AGENT_SDKCONFIG_CONTENT "${EDGE_AGENT_SDKCONFIG_CONTENT}")
        string(REGEX REPLACE "(^|\\n)CONFIG_PARTITION_TABLE_FILENAME=\"[^\\n]*\"\\n" "\\1" EDGE_AGENT_SDKCONFIG_CONTENT "${EDGE_AGENT_SDKCONFIG_CONTENT}")
        if(NOT EDGE_AGENT_SDKCONFIG_CONTENT MATCHES "\\n$")
            string(APPEND EDGE_AGENT_SDKCONFIG_CONTENT "\n")
        endif()
        file(WRITE "${CMAKE_SOURCE_DIR}/sdkconfig" "${EDGE_AGENT_SDKCONFIG_CONTENT}")
    endif()

    set(EDGE_AGENT_PARTITION_DEFAULTS "${CMAKE_BINARY_DIR}/edge_agent_partition_auto.defaults")
    if(NOT EDGE_AGENT_PARTITION_FILENAME)
        set(EDGE_AGENT_PARTITION_FILENAME "partitions_${EDGE_AGENT_FLASH_SIZE}.csv")
    endif()
    file(WRITE "${EDGE_AGENT_PARTITION_DEFAULTS}"
        "# Auto-generated from flash size selection. Do not edit.\n"
        "CONFIG_PARTITION_TABLE_CUSTOM=y\n"
        "CONFIG_PARTITION_TABLE_CUSTOM_FILENAME=\"${EDGE_AGENT_PARTITION_FILENAME}\"\n")

    if(SDKCONFIG_DEFAULTS)
        set(SDKCONFIG_DEFAULTS "${SDKCONFIG_DEFAULTS};${EDGE_AGENT_PARTITION_DEFAULTS}")
    elseif(NOT "$ENV{SDKCONFIG_DEFAULTS}" STREQUAL "")
        set(SDKCONFIG_DEFAULTS "$ENV{SDKCONFIG_DEFAULTS};${EDGE_AGENT_PARTITION_DEFAULTS}")
    else()
        set(SDKCONFIG_DEFAULTS "${CMAKE_SOURCE_DIR}/sdkconfig.defaults;${EDGE_AGENT_PARTITION_DEFAULTS}")
    endif()

    message(STATUS "${EDGE_AGENT_PROJECT_LOG_PREFIX} Partition table auto-selected: partitions_${EDGE_AGENT_FLASH_SIZE}.csv")
endif()
