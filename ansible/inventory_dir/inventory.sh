#!/usr/bin/env bash
task terraform-output 2>/dev/null | python3 inventory_dir/hosts111.py && ansible-inventory -i inventory --list
