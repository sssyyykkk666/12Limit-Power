import json, os, pathlib, shutil, subprocess, tempfile, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
MOCK='''#!/usr/bin/python3
import json,pathlib,sys
p=pathlib.Path(__file__).with_name('mock.json');s=json.loads(p.read_text());a=sys.argv[1:]
if a[0]=='read': print('('+format(int(s[a[1]],16),'064b')+')')
elif a[0]=='write':
 s['writes']+=1
 if s.pop('rejectNext',False): pass
 else:s[a[1]]=a[2]
 p.write_text(json.dumps(s))
elif a[0]=='turbo':
 v=int(s['1a0'],16);v=(v&~(1<<38)) | ((0 if a[1]=='1' else 1)<<38);s['1a0']=format(v,'016x');p.write_text(json.dumps(s))
elif a[0]=='info':print('CPU Freq: 1.2ghz, Power:pkg 4.2w,Temp: 60 c')
'''
class ControllerTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.base=pathlib.Path(self.tmp.name)/'backend';self.base.mkdir();self.req=pathlib.Path(self.tmp.name)/'request'
  shutil.copy(ROOT/'scripts/power-policy.pl',self.base)
  (self.base/'voltageshift').write_text(MOCK);(self.base/'voltageshift').chmod(0o755)
  self.orig='0042818800dd8188';self.origTurbo='0000000000850089'
  self.state={'610':self.orig,'1a0':self.origTurbo,'606':'00000000000a0e03','writes':0}
  self.setstate(self.state)
  for key,val in [('power',self.orig),('turbo',self.origTurbo)]:
   subprocess.run(['/usr/bin/defaults','write',str(self.base/'baseline'),key,'-string',val],check=True)
  src=(ROOT/'scripts/controller.sh').read_text().replace('/Users/skyfu/Library/Application Support/FYQMacControl/request',str(self.req)).replace('/Library/Application Support/FYQMac',str(self.base))
  self.script=pathlib.Path(self.tmp.name)/'controller.sh';self.script.write_text(src)
 def tearDown(self):self.tmp.cleanup()
 def setstate(self,s):(self.base/'mock.json').write_text(json.dumps(s))
 def getstate(self):return json.loads((self.base/'mock.json').read_text())
 def runrequest(self,req):
  self.req.write_text(req+'\ntest-uuid\n');r=subprocess.run(['bash',str(self.script)],capture_output=True,text=True)
  self.assertEqual(r.returncode,0,r.stderr);self.assertFalse(self.req.exists());return (self.base/'status.txt').read_text()
 def test_custom_persist_reapply_restore_refresh(self):
  self.assertIn('已回读验证',self.runrequest('custom 36 48 0 8'))
  s=self.getstate();self.assertEqual(int(s['610'],16)&0x7fff,36);self.assertTrue(int(s['1a0'],16)&(1<<38))
  self.assertEqual((self.base/'custom.txt').read_text().strip(),'36 48 0 8')
  self.assertIn('已回读验证',self.runrequest('reapply'))
  before=self.getstate()['writes'];self.assertIn('配置未改动',self.runrequest('refresh'));self.assertEqual(self.getstate()['writes'],before)
  self.assertIn('已回读验证',self.runrequest('original'));self.assertEqual(self.getstate()['610'],self.orig);self.assertEqual(self.getstate()['1a0'],self.origTurbo)
 def test_invalid_request_no_writes(self):
  for request in ['custom 29 48 1 0','custom 40 39 1 0','custom 40 393 1 0','custom 40 48 1 3','custom 40;echo 48 1 0','unknown']:
   self.runrequest(request);self.assertEqual(self.getstate()['writes'],0)
 def test_readback_failure_rolls_back(self):
  s=self.getstate();s['rejectNext']=True;self.setstate(s)
  self.assertIn('已回退并验证',self.runrequest('custom 36 48 0 8'))
  self.assertEqual(self.getstate()['610'],self.orig);self.assertEqual(self.getstate()['1a0'],self.origTurbo)
  self.assertFalse((self.base/'settings.json').exists())
 def test_legacy_profiles_and_request(self):
  for profile in ['quiet','balance','original']:
   self.assertIn('已回读验证',self.runrequest(profile))
if __name__=='__main__':unittest.main()
