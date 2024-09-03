import os, sys
import json
from tqdm import tqdm


file_path = sys.argv[-1]

def get_opcodes():
    with open('./opcodes.json', 'r') as f:
        data = json.load(f)
    return data

def filter_for_flag(operands):
    out = []
    for operand in operands:
        if (operand['name'] == 'NC'):
            out.append( lambda x: x[3] == '0' )
        elif (operand['name'] == 'C'):
            out.append( lambda x: x[3] == '1' )
        elif (operand['name'] == 'NZ'):
            out.append( lambda x: x[0] == '0' )
        elif (operand['name'] == 'Z'):
            out.append( lambda x: x[0] == '1' )
    return out



def parse(file_path):
    print(f"Opening file: {file_path}")
    data = {}
    current_op = None
    op_name = None
    ZNHC = None
    op_set = False
    prefixed = False

    ops = get_opcodes()['unprefixed']
    ops_prefixed = get_opcodes()['cbprefixed']

    with open(file_path, 'r', encoding='windows-1252') as f:
        for line in tqdm(f.readlines()):
            if "FlagsRegister" in line:
                line = ' '.join(line.split())
                line = line.split(' ')
                tentative_op = line[4].replace('(', '')
                if tentative_op in data.keys():
                    continue
                if 'CB' == line[3]:
                    prefixed = True
                    tentative_op = line[5]
                    gt_op = ops_prefixed['0x' + tentative_op]
                    op_name = gt_op['mnemonic']
                else:
                    op_name = line[3]
                current_op = tentative_op 
                op_set = True
                ZNHC = line[-2].replace(',','') + \
                    line[-5].replace(',','') + \
                    line[-8].replace(',', '') + \
                    line[-11].replace(',','')
                continue

            if op_set and ("Num Bytes" in line):
                line = line.strip('\n')
                op_set = False
                line = line.split(" ")
                num_bytes = line[3]
                num_cycles = line[-1]
                if current_op not in data:
                    gt = ops[f"0x{current_op}"] if not prefixed else ops_prefixed[f"0x{current_op}"]
                    prefixed = False
                    if gt['cycles'][0] != int(num_cycles):
                        conditions = filter_for_flag(gt['operands'])
                        if len(conditions) > 0 and len(gt['cycles']) > 1:
                            skip = True
                            for condition in conditions:
                                skip = skip and condition(ZNHC)
                            if skip:
                                continue 
                            if gt['cycles'][1] != int(num_cycles):
                                data[current_op] = {
                                    'cycle': num_cycles,
                                    'bytes': num_bytes,
                                    'name' : op_name,
                                    'gt': str(gt['cycles'][1]),
                                    'znhc': ZNHC if ZNHC is not None else "",
                                }
                        else:
                            data[current_op] = {
                                'cycle': num_cycles,
                                'bytes': num_bytes,
                                'name' : op_name,
                                'gt': str(gt['cycles'][0]),
                                'znhc': ZNHC if ZNHC is not None else "",
                            }

    print("| {:<5} | {:<5} | {:<5} | {:<6} | {:<5} | {:<5} |".format('OP', 'name', 'bytes', 'cycles', 'gt', 'znhc'))
    for ind in range(255):
        hex_key = "%0.2X" % ind
        if hex_key in data.keys():
            k = hex_key
            v = data[k]
            print("| {:<5} | {:<5} | {:<5} | {:<6} | {:<5} | {:<5} |".format(k, v['name'], v['bytes'], v['cycle'], v['gt'], v['znhc']))


    return



parse(file_path)
