#!/usr/bin/python3

import os
import io
import glob
import yaml
import re
from pathlib import Path
import sys

if len(sys.argv) != 3:
    print("Usage: cnssi-merge.py <pathToProject> <pathToCNSSICustoms>")
    sys.exit(1)

pathToProject = sys.argv[1]
pathToCNSSICustoms = sys.argv[2]

for ruleCNSSI in glob.glob(pathToCNSSICustoms + '/*/rules/*/*'):
    if "supplemental" in ruleCNSSI:
        continue

    file = Path(pathToProject + "rules" + ruleCNSSI.split("rules")[1])
    if file.is_file():
        with open(ruleCNSSI) as r1:
            rule_cnssi_yaml = yaml.load(r1, Loader=yaml.SafeLoader)
        print(file)

        tags = rule_cnssi_yaml.get('tags', [''])
        print(tags)

        rule = str(file)
        with open(rule) as r2:
            rule_yaml = yaml.load(r2, Loader=yaml.SafeLoader)

        if 'severity' in rule_yaml:
            cnssitag = '\n- {}\nseverity:'.format(tags[0])
            print(cnssitag)
            with open(rule) as r3:
                yaml_rule = r3.read()
            yaml_rule = yaml_rule.replace("\nseverity:", cnssitag)
            with open(rule, 'w') as rite1:
                rite1.write(yaml_rule)
            print(yaml_rule)
            print(cnssitag)
        else:
            cnssitag = '\n- {}\nmobileconfig:'.format(tags[0])
            print(cnssitag)
            with open(rule) as r4:
                yaml_rule = r4.read()
            yaml_rule = yaml_rule.replace("\nmobileconfig:", cnssitag)
            with open(rule, 'w') as rite2:
                rite2.write(yaml_rule)
            print(yaml_rule)
            print(cnssitag)
    else:
        print("File: {} not found".format(file))
