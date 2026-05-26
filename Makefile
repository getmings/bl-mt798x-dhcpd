# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2026 Yuzhii0718
#
# All rights reserved.
#
# This file is part of the project bl-mt798x-dhcpd
# You may not use, copy, modify or distribute this file except in compliance with the license agreement.
#
# Quick Build Scripts
#

.DEFAULT_GOAL := all
SHELL := /bin/bash

VERSION ?= 2025
VARIANT ?= default
FSTHEME ?= bootstrap
MULTI_LAYOUT ?= 1
FIXED_MTDPARTS ?= 1
SIMG ?= 0
COPY_BL2 ?= 1
SILENT ?= Y

ATFCFG_DIR ?= mt798x_atf
CFG_SUBDIR ?=
OUTPUT_DIR ?= output_bl2
SHOW ?= 0
DRAW ?= 0
SDMMC ?= 0

BOARD ?=
ATF_DIR ?=
UBOOT_DIR ?=

.PHONY: all build boards board-configs atf gpt clean help

all:
	@set -euo pipefail; \
	case "$(VERSION)" in \
		2025) ATF_DIR="atf-20250711"; UBOOT_DIR="uboot-mtk-20250711" ;; \
		SP1|sp1) ATF_DIR="atf-20240117-bacca82a8"; UBOOT_DIR="uboot-mtk-20250711" ;; \
		SP2|sp2) ATF_DIR="atf-20260123"; UBOOT_DIR="uboot-mtk-20250711" ;; \
		*) echo "Error: unsupported VERSION='$(VERSION)'." >&2; echo "Supported: 2025/SP1/SP2" >&2; exit 1 ;; \
	esac; \
	collect_board_configs() { \
		local atf_cfg_dir="$$ATF_DIR/configs"; \
		local uboot_cfg_dir="$$UBOOT_DIR/configs"; \
		local atf_list uboot_list; \
		if [[ ! -d "$$atf_cfg_dir" || ! -d "$$uboot_cfg_dir" ]]; then \
			echo "Error: both configs directories must exist:" >&2; \
			echo "  $$atf_cfg_dir" >&2; \
			echo "  $$uboot_cfg_dir" >&2; \
			return 1; \
		fi; \
		atf_list="$$(mktemp)"; \
		uboot_list="$$(mktemp)"; \
		trap 'rm -f "$$atf_list" "$$uboot_list"' RETURN; \
		find -L "$$atf_cfg_dir" -maxdepth 1 -type f -name '*_defconfig' -printf '%f\n' | sed 's/_defconfig$$//' | sort -u > "$$atf_list"; \
		find -L "$$uboot_cfg_dir" -maxdepth 1 -type f -name '*_defconfig' -printf '%f\n' | sed 's/_defconfig$$//' | sort -u > "$$uboot_list"; \
		comm -12 "$$atf_list" "$$uboot_list"; \
	}; \
	build_one_board() { \
		local cfg_base="$$1"; \
		local soc="$${cfg_base%%_*}"; \
		local board="$${cfg_base#*_}"; \
		local log_file="output/build-$${board}-$(VERSION)-$(VARIANT).log"; \
		mkdir -p output; \
		echo "----------------------------------------------------------------------"; \
		echo "Building BOARD=$$board (SOC=$$soc, VERSION=$(VERSION), VARIANT=$(VARIANT))"; \
		echo "Log: $$log_file"; \
		printf '%s\n' "env -u MAKEFLAGS -u MAKELEVEL -u MFLAGS BOARD=\"$$board\" VERSION=\"$(VERSION)\" VARIANT=\"$(VARIANT)\" FSTHEME=\"$(FSTHEME)\" MULTI_LAYOUT=\"$(MULTI_LAYOUT)\" FIXED_MTDPARTS=\"$(FIXED_MTDPARTS)\" SIMG=\"$(SIMG)\" COPY_BL2=\"$(COPY_BL2)\" SILENT=\"$(SILENT)\" ./build.sh 2>&1 | tee \"$$log_file\""; \
		env -u MAKEFLAGS -u MAKELEVEL -u MFLAGS \
		BOARD="$$board" VERSION="$(VERSION)" VARIANT="$(VARIANT)" FSTHEME="$(FSTHEME)" \
		MULTI_LAYOUT="$(MULTI_LAYOUT)" FIXED_MTDPARTS="$(FIXED_MTDPARTS)" SIMG="$(SIMG)" \
		COPY_BL2="$(COPY_BL2)" SILENT="$(SILENT)" ./build.sh 2>&1 | tee "$$log_file"; \
	}; \
	mapfile -t board_cfgs < <(collect_board_configs); \
	if [[ "$(BOARD)" != "" ]]; then \
		match=""; \
		for cfg in "$${board_cfgs[@]}"; do \
			cfg_board="$${cfg#*_}"; \
			if [[ "$$cfg_board" == "$(BOARD)" ]]; then \
				match="$$cfg"; \
				break; \
			fi; \
		done; \
		if [[ -z "$$match" ]]; then \
			echo "Error: BOARD='$(BOARD)' is not found in the intersection of $$ATF_DIR/configs and $$UBOOT_DIR/configs." >&2; \
			echo "Available boards:" >&2; \
			printf '  %s\n' "$${board_cfgs[@]#*_}" >&2; \
			exit 1; \
		fi; \
		build_one_board "$$match"; \
	else \
		if [[ "$${#board_cfgs[@]}" -eq 0 ]]; then \
			echo "Error: no buildable BOARD found under $$ATF_DIR/configs and $$UBOOT_DIR/configs." >&2; \
			exit 1; \
		fi; \
		success_count=0; \
		fail_count=0; \
		total_count="$${#board_cfgs[@]}"; \
		index=0; \
		for cfg in "$${board_cfgs[@]}"; do \
			index=$$((index + 1)); \
			cfg_board="$${cfg#*_}"; \
			echo "[$$index/$$total_count] $$cfg_board"; \
			if build_one_board "$$cfg"; then \
				success_count=$$((success_count + 1)); \
			else \
				fail_count=$$((fail_count + 1)); \
				echo "Build failed for BOARD=$$cfg_board, continuing..." >&2; \
			fi; \
		done; \
		echo "----------------------------------------------------------------------"; \
		echo "Build summary: success=$$success_count, failed=$$fail_count, total=$$total_count"; \
		if [[ "$$fail_count" -gt 0 ]]; then \
			exit 1; \
		fi; \
	fi

build: all

boards:
	@set -euo pipefail; \
	case "$(VERSION)" in \
		2025) ATF_DIR="atf-20250711"; UBOOT_DIR="uboot-mtk-20250711" ;; \
		SP1|sp1) ATF_DIR="atf-20240117-bacca82a8"; UBOOT_DIR="uboot-mtk-20250711" ;; \
		SP2|sp2) ATF_DIR="atf-20260123"; UBOOT_DIR="uboot-mtk-20250711" ;; \
		*) echo "Error: unsupported VERSION='$(VERSION)'." >&2; exit 1 ;; \
	esac; \
	collect_board_configs() { \
		local atf_cfg_dir="$$ATF_DIR/configs"; \
		local uboot_cfg_dir="$$UBOOT_DIR/configs"; \
		local atf_list uboot_list; \
		atf_list="$$(mktemp)"; \
		uboot_list="$$(mktemp)"; \
		trap 'rm -f "$$atf_list" "$$uboot_list"' RETURN; \
		find -L "$$atf_cfg_dir" -maxdepth 1 -type f -name '*_defconfig' -printf '%f\n' | sed 's/_defconfig$$//' | sort -u > "$$atf_list"; \
		find -L "$$uboot_cfg_dir" -maxdepth 1 -type f -name '*_defconfig' -printf '%f\n' | sed 's/_defconfig$$//' | sort -u > "$$uboot_list"; \
		comm -12 "$$atf_list" "$$uboot_list"; \
	}; \
	mapfile -t board_cfgs < <(collect_board_configs); \
	if [[ "$${#board_cfgs[@]}" -eq 0 ]]; then \
		echo "No buildable BOARD found."; \
		exit 0; \
	fi; \
	echo "Buildable BOARD list (intersection of $$ATF_DIR/configs and $$UBOOT_DIR/configs):"; \
	printf '  %s\n' "$${board_cfgs[@]#*_}"

board-configs:
	@set -euo pipefail; \
	case "$(VERSION)" in \
		2025) ATF_DIR="atf-20250711"; UBOOT_DIR="uboot-mtk-20250711" ;; \
		SP1|sp1) ATF_DIR="atf-20240117-bacca82a8"; UBOOT_DIR="uboot-mtk-20250711" ;; \
		SP2|sp2) ATF_DIR="atf-20260123"; UBOOT_DIR="uboot-mtk-20250711" ;; \
		*) echo "Error: unsupported VERSION='$(VERSION)'." >&2; exit 1 ;; \
	esac; \
	collect_board_configs() { \
		local atf_cfg_dir="$$ATF_DIR/configs"; \
		local uboot_cfg_dir="$$UBOOT_DIR/configs"; \
		local atf_list uboot_list; \
		atf_list="$$(mktemp)"; \
		uboot_list="$$(mktemp)"; \
		trap 'rm -f "$$atf_list" "$$uboot_list"' RETURN; \
		find -L "$$atf_cfg_dir" -maxdepth 1 -type f -name '*_defconfig' -printf '%f\n' | sed 's/_defconfig$$//' | sort -u > "$$atf_list"; \
		find -L "$$uboot_cfg_dir" -maxdepth 1 -type f -name '*_defconfig' -printf '%f\n' | sed 's/_defconfig$$//' | sort -u > "$$uboot_list"; \
		comm -12 "$$atf_list" "$$uboot_list"; \
	}; \
	mapfile -t board_cfgs < <(collect_board_configs); \
	printf '%s\n' "$${board_cfgs[@]}"

atf:
	@set -euo pipefail; \
	printf '%s\n' "env -u MAKEFLAGS -u MAKELEVEL -u MFLAGS ATF_DIR=\"$(ATF_DIR)\" VERSION=\"$(VERSION)\" VARIANT=\"$(VARIANT)\" ATFCFG_DIR=\"$(ATFCFG_DIR)\" CFG_SUBDIR=\"$(CFG_SUBDIR)\" OUTPUT_DIR=\"$(OUTPUT_DIR)\" OC7981=\"$(OC7981)\" OC7986=\"$(OC7986)\" TOOLCHAIN=\"$(TOOLCHAIN)\" ./compile_atf.sh"; \
	env -u MAKEFLAGS -u MAKELEVEL -u MFLAGS \
	ATF_DIR="$(ATF_DIR)" VERSION="$(VERSION)" VARIANT="$(VARIANT)" \
	ATFCFG_DIR="$(ATFCFG_DIR)" CFG_SUBDIR="$(CFG_SUBDIR)" OUTPUT_DIR="$(OUTPUT_DIR)" \
	OC7981="$(OC7981)" OC7986="$(OC7986)" TOOLCHAIN="$(TOOLCHAIN)" ./compile_atf.sh

gpt:
	@set -euo pipefail; \
	printf '%s\n' "env -u MAKEFLAGS -u MAKELEVEL -u MFLAGS VERSION=\"$(VERSION)\" SHOW=\"$(SHOW)\" DRAW=\"$(DRAW)\" SDMMC=\"$(SDMMC)\" ./generate_gpt.sh"; \
	env -u MAKEFLAGS -u MAKELEVEL -u MFLAGS \
	VERSION="$(VERSION)" SHOW="$(SHOW)" DRAW="$(DRAW)" SDMMC="$(SDMMC)" ./generate_gpt.sh

clean:
	@set -euo pipefail; \
	printf '%s\n' "env -u MAKEFLAGS -u MAKELEVEL -u MFLAGS CLEAN=1 VERSION=\"$(VERSION)\" ./build.sh"; \
	env -u MAKEFLAGS -u MAKELEVEL -u MFLAGS CLEAN=1 VERSION="$(VERSION)" ./build.sh

help:
	@printf '%s\n' \
		'Quick build entry points' \
		'' \
		'Usage:' \
		'  make                     # build all BOARDs found in the intersection of atf/configs and uboot/configs' \
		'  make BOARD=<board>       # build a single BOARD' \
		'  make atf                 # call compile_atf.sh' \
		'  make gpt                 # call generate_gpt.sh' \
		'  make boards              # list buildable BOARDs' \
		'  make board-configs       # list buildable config names (for automation)' \
		'  make help                # show this help' \
		'' \
		'Common variables:' \
		'  VERSION=2025|SP1|SP2' \
		'  VARIANT=default|ubootmod|nonmbm|openwrt' \
		'  FSTHEME=bootstrap|gl|mtk' \
		'  MULTI_LAYOUT=0|1' \
		'  FIXED_MTDPARTS=0|1' \
		'  SIMG=0|1' \
		'  SILENT=Y|N' \
		'' \
		'ATF / GPT helpers:' \
		'  make atf ATFCFG_DIR=mt798x_atf CFG_SUBDIR=normal OUTPUT_DIR=output_bl2' \
		'  make gpt SHOW=1' \
		'  make gpt DRAW=1' \
		'  make gpt SDMMC=1' \
		'' \
		'Notes:' \
		'  - BOARD discovery only uses the default configs directories, and only keeps entries' \
		'    that exist in both ATF and U-Boot, matching the FIP build workflow.' \
		'  - make runs with SILENT=Y by default so batch builds do not stop for prompts.'