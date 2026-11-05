import json, subprocess, sys
out = subprocess.run(['dart', 'analyze', '--format=json'], capture_output=True, text=True, cwd=r'C:\Users\chenl\OneDrive\Desktop\CICD stuff\Assignment Submission\CA1_CICD_Project\frontend')
try:
    data = json.loads(out.stdout)
    errs = [d for d in data['diagnostics'] if d['severity'] == 'ERROR']
    warns = [d for d in data['diagnostics'] if d['severity'] == 'WARNING']
    infos = [d for d in data['diagnostics'] if d['severity'] == 'INFO']
    print(f"ERRORS: {len(errs)}")
    for e in errs:
        loc = e['location']
        fname = loc['file'].replace('C:\\Users\\chenl\\OneDrive\\Desktop\\CICD stuff\\Assignment Submission\\CA1_CICD_Project\\frontend\\', '')
        print(f"{fname}:{loc['range']['start']['line']+1}:{loc['range']['start']['column']} {e['problemMessage']}")
    print(f"\nWARNINGS: {len(warns)}")
    # Group warnings by type
    from collections import Counter
    c = Counter()
    for w in warns:
        c[w.get('code', {}).get('name', 'unknown')] += 1
    for code, count in c.most_common(15):
        print(f"  {code}: {count}")
    print(f"\nINFOS: {len(infos)}")
    sys.exit(0 if not errs else 1)
except:
    print(out.stdout[:500])
    print(out.stderr[:500])
    sys.exit(1)
