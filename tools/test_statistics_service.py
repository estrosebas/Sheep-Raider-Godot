"""Exercise the real HTTP service with an isolated SQLite database."""
import importlib.util
import json
from pathlib import Path
import tempfile
import threading
import unittest
from urllib.request import Request, urlopen
from urllib.error import HTTPError
from http.server import ThreadingHTTPServer

spec=importlib.util.spec_from_file_location('stats',Path(__file__).resolve().parents[1]/'deploy/statistics_service.py')
stats=importlib.util.module_from_spec(spec);spec.loader.exec_module(stats)

class StatisticsTests(unittest.TestCase):
    def setUp(self):
        self.directory=tempfile.TemporaryDirectory()
        self.database=Path(self.directory.name)/'counts.sqlite'
        self.server=ThreadingHTTPServer(('127.0.0.1',0),stats.handler(self.database))
        self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start()
        self.url='http://127.0.0.1:'+str(self.server.server_port)
    def tearDown(self):
        self.server.shutdown();self.server.server_close();self.thread.join();self.directory.cleanup()
    def event(self, **overrides):
        value={'kind':'session','platform':'android','version':'1.0.3','event':'a'*32,'consent':'v1'}
        value.update(overrides);return value
    def post(self, body, origin=None):
        headers={'Content-Type':'application/json'}
        if origin:headers['Origin']=origin
        request=Request(self.url+'/api/stats/events',data=json.dumps(body).encode(),headers=headers)
        try:
            with urlopen(request,timeout=3) as response:return response.status
        except HTTPError as error:
            code=error.code;error.close();return code
    def test_retry_deduplication_and_platform_separation(self):
        self.assertEqual(self.post(self.event()),202)
        self.assertEqual(self.post(self.event()),202)
        self.assertEqual(self.post(self.event(platform='windows',event='b'*32)),202)
        self.assertEqual(self.post(self.event(platform='web',event='c'*32)),202)
        self.assertEqual(self.post(self.event(kind='download',event='d'*32)),202)
        rows=stats.report(self.database)
        self.assertEqual(sum(row['total'] for row in rows),4)
        self.assertEqual({row['platform'] for row in rows},{'android','web','windows'})
    def test_consent_and_unknown_fields_rejected(self):
        for body in (self.event(consent='no'), self.event(ip='1.2.3.4'),self.event(platform='ios'),self.event(event='device-id'),self.event(kind='download',platform='web'), ['invalid']):
            self.assertEqual(self.post(body),400)
        self.assertEqual(stats.report(self.database),[])
    def test_origin_and_private_report(self):
        self.assertEqual(self.post(self.event(),origin='https://evil.example'),403)
        with self.assertRaises(HTTPError) as error:urlopen(self.url+'/api/stats/report')
        self.assertEqual(error.exception.code,404)
    def test_no_personal_data_columns(self):
        self.post(self.event())
        with stats.connect(self.database) as db:
            self.assertEqual([row[1] for row in db.execute('PRAGMA table_info(counts)')],['day','kind','platform','version','total'])

if __name__=='__main__':unittest.main()
