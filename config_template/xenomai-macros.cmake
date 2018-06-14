
if(CMAKE_VERSION VERSION_LESS 3.5)
include(CMakeParseArguments)
endif()

# define _XENOMAI_BOOTSTRAP_MODNAME "target"

# X - add sources to target (CMake 3.0 / 3.1 needed), fallback Y if no header
# Y - link precompiled object to target (test)
# Z - wrap main via macro
# L - wrap main via linker
# target sources and source generator expressions only available with CMake 3.1
#
# Generator expressions are always preferred,
# if
# source
# wrapmain MACRO
# wrapmain
function(xenomai_target_bootstrap target)

	set(_fileprefix "${CMAKE_CURRENT_BINARY_DIR}/generated/xenomai_bootstrap")
	# __real_main?
	file(WRITE "${_fileprefix}_main.c" "#ifdef main\n#undef main\n#endif\n#define _XENOMAI_BOOTSTRAP_DEFINE_MAINWRAPPER __real_main\n#define _XENOMAI_BOOTSTRAP_WEAKREF_MAINWRAPPER main\n#include <xenomai/bootstrap-template.h>")
	file(WRITE "${_fileprefix}_shl.c" "#define _XENOMAI_BOOTSTRAP_DSO\n#include <xenomai/bootstrap-template.h>")
	file(WRITE "${_fileprefix}.c" "#include <xenomai/bootstrap-template.h>")

	get_target_property(ttype ${target} TYPE)

	cmake_parse_arguments(XBS "NO_FALLBACK" "MAIN;MAIN_WRAP" "SKINS" ${ARGN})
	set(_errors)

	if(XBS_MAIN AND NOT XBS_MAIN STREQUAL "NONE" AND NOT XBS_MAIN STREQUAL "SOURCE" AND NOT XBS_MAIN STREQUAL "PRECOMPILED")
		set(_errors ${_errors} "MAIN only support the values NONE, SOURCE and PRECOMPILED")
	endif()
	if(XBS_MAIN_WRAP AND NOT XBS_MAIN_WRAP STREQUAL "NONE" AND NOT XBS_MAIN_WRAP STREQUAL "MACRO" AND NOT XBS_MAIN_WRAP STREQUAL "LINKER")
		set(_errors ${_errors} "XBS_MAIN_WRAP only support the values NONE, MACRO and LINKER")
	endif()

	# the default is not working on CMake 3.0, so fallback to
	# the precompiled objects unless this was disabled
	if(CMAKE_VERSION VERSION_LESS 3.1)
		if(NOT XBS_MAIN OR XBS_MAIN STREQUAL "NONE" OR XBS_MAIN STREQUAL "SOURCE")
			if(XBS_NO_FALLBACK)
				set(_errors ${_errors} "MAIN NONE and MAIN SOURCE need atleast CMake 3.1")
			else()
				if(ttype STREQUAL EXECUTABLE)
					message(WARNING "xenomai_target_bootstrap: setting MAIN PRECOMPILED for ${target} (CMake Version less than 3.1)")
				endif()
				set(XBS_MAIN "PRECOMPILED")
			    if(NOT XBS_MAIN_WRAP OR XBS_MAIN_WRAP STREQUAL "NONE" OR XBS_MAIN_WRAP STREQUAL "MACRO")
			    	set(XBS_MAIN_WRAP "LINKER")
			    	if(ttype STREQUAL EXECUTABLE)
						message(WARNING "xenomai_target_bootstrap: setting XBS_MAIN_WRAP LINKER for ${target} (CMake Version less than 3.1)")
					endif()
			    endif()
			endif()
		endif()
	endif()

	if(_errors)
		message(SEND_ERROR "xenomai_target_bootstrap: ${_errors}")
		return()
	endif()

	if(XBS_MAIN STREQUAL "SOURCE")
		target_sources(${target} PRIVATE
			"$<$<STREQUAL:$<TARGET_PROPERTY:TYPE>,SHARED_LIBRARY>:${_fileprefix}_shl.c>"
			"$<$<STREQUAL:$<TARGET_PROPERTY:TYPE>,EXECUTABLE>:${_fileprefix}_main.c>"
		)

	elseif(XBS_MAIN STREQUAL "PRECOMPILED")
		target_link_libraries(${target} PRIVATE
			Xenomai::legacy_bootstrap
		)

	else()
		target_sources(${target} PRIVATE
		    "$<$<STREQUAL:$<TARGET_PROPERTY:TYPE>,SHARED_LIBRARY>:${_fileprefix}_shl.c>"
			"$<$<STREQUAL:$<TARGET_PROPERTY:TYPE>,EXECUTABLE>:${_fileprefix}.c>"
		)

	endif()

	if(XBS_MAIN_WRAP STREQUAL "MACRO")
		target_compile_definitions(${target} PRIVATE
		    $<$<STREQUAL:$<TARGET_PROPERTY:TYPE>,EXECUTABLE>:main=__real_main>
		)

	elseif(XBS_MAIN_WRAP STREQUAL "LINKER")
		target_link_libraries(${target} PRIVATE
			Xenomai::legacy_bootstrap_wrap
		)
	endif()

	set(_skins)
	foreach(skin ${XBS_SKINS})
		set(_skins ${_skins} "Xenomai::${skin}")
	endforeach()

	if(_skins)
		target_link_libraries(${target} PRIVATE
			${_skins}
		)
	endif()
endfunction()
