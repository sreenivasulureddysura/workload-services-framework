
function(show_backend_settings)
    message("-- Setting: TERRAFORM_OPTIONS=${TERRAFORM_OPTIONS}")
    message("-- Setting: TERRAFORM_SUT=${TERRAFORM_SUT}")
    if(DEFINED SPOT_INSTANCE)
        message("-- Setting: SPOT_INSTANCE=${SPOT_INSTANCE}")
    else()
        set(spot_found "")
        string(REPLACE " " ";" suts "${TERRAFORM_SUT}")
        foreach(sut ${suts})
            execute_process(COMMAND sed -n "/^\\s*variable\\s*[\"]spot_instance[\"]\\s*[{]/,/^\\s*[}]/p" "terraform-config.${sut}.tf" WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}/script/terraform" ERROR_QUIET OUTPUT_VARIABLE spot_det)
            if(spot_det MATCHES "true")
                set(spot_found "${spot_found} ${sut}")
            endif()
        endforeach()
        if(spot_found)
            STRING(ASCII 27 esc)
            message("")
            message("${esc}[31mWARNING:${esc}[m SPOT instance detected in SUT:${spot_found}")
            message("For performance benchmarking, 'cmake -DSPOT_INSTANCE=false ..'")
        endif()
    endif()
endfunction()

function(add_backend_dependencies type name)
    add_dependencies(build_${name} build_terraform)
    set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_MAKE_CLEAN_FILES "${CMAKE_CURRENT_BINARY_DIR}/.signature")
endfunction()

function(add_backend_tools type)
    execute_process(COMMAND ln -s -r -f "${PROJECT_SOURCE_DIR}/script/terraform/script/debug.sh" . WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}")
endfunction()

function(add_backend_testcase type component name)
    if(";${sut_reqs};" STREQUAL ";;")
        string(REPLACE " " ";" terraform_sut "${TERRAFORM_SUT}")
        set(sut_list "")
        foreach(sut1 ${terraform_sut})
            if(NOT sut1 MATCHES "^-")
                set(sut_list "${sut_list};${sut1}")
            endif()
        endforeach()
    else()
        set(sut_list "${sut_reqs}")
    endif()
    foreach(sut1 ${sut_list})
        if(sut1 AND (" ${TERRAFORM_SUT} " MATCHES " ${sut1} "))
            string(REGEX REPLACE "^-" "" sut2 "${sut1}")
            add_testcase_1("${sut2}_${name}" "BACKEND=${BACKEND} ${BACKEND_ENVS} TERRAFORM_CONFIG_IN='${PROJECT_SOURCE_DIR}/script/terraform/terraform-config.${sut1}.tf'" ${ARGN})
        endif()
    endforeach()
endfunction()

################ TOP-LEVEL-CMAKE ###########################

execute_process(COMMAND bash -c "echo \"\"$(find -name 'terraform-config.*.tf' | sed 's|.*/terraform-config.\\(.*\\).tf$|\\1|')" OUTPUT_VARIABLE sut_all OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/script/terraform")

if (NOT TERRAFORM_OPTIONS)
    set(TERRAFORM_OPTIONS "--docker --nosvrinfo --intel_publish")
elseif (PLATFORM MATCHES "GRAVITON")
    string(REGEX REPLACE "--emon *" "" TERRAFORM_OPTIONS "${TERRAFORM_OPTIONS}")
endif()

if ((NOT DEFINED TERRAFORM_SUT) OR (TERRAFORM_SUT STREQUAL ""))
    set(TERRAFORM_SUT "${sut_all}")
endif()

string(REPLACE " " ";" configs "${TERRAFORM_SUT}")
foreach(config ${configs})
    if(NOT " ${sut_all} " MATCHES " ${config} ")
        message(FATAL_ERROR "Failed to locate terraform config: ${config}")
    endif()
endforeach()

set(BACKEND_ENVS "TERRAFORM_OPTIONS='${TERRAFORM_OPTIONS}' TERRAFORM_SUT='${TERRAFORM_SUT}'")
if(DEFINED SPOT_INSTANCE)
  if(SPOT_INSTANCE)
    set(SPOT_INSTANCE "true")
  else()
    set(SPOT_INSTANCE "false")
  endif()
  set(BACKEND_ENVS "${BACKEND_ENVS} SPOT_INSTANCE='${SPOT_INSTANCE}'")
endif()
add_subdirectory(script/csp)
add_subdirectory(script/terraform)
