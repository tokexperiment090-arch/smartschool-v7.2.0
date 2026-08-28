<?php
// Portal module for Riyo — clones the Mustaqbal/Kaafiye dynamic-form portal.
// Pages addressed by ?p=PAGEID (mirrors Mustaqbal). Self-provisions tables + seeds
// the 130 cloned modules on first load. Login-gated (mirrors Mustaqbal auth).
// Backend + DB fully working.
defined('BASEPATH') OR exit('No direct script access allowed');

class Portal extends CI_Controller {

    // Real field schemas for the key Mustaqbal modules (id => fields).
    private $schemas = array(
        19004 => array('label'=>'Qasnad Cusub (New Account)','type'=>'horizontal','fields'=>array(
            array('name'=>'account_code','label'=>'Account Code','type'=>'text'),
            array('name'=>'account_name','label'=>'Account Name','type'=>'text'),
            array('name'=>'account_type','label'=>'Account Type','type'=>'select','options'=>array('Asset','Liability','Equity','Income','Expense')),
            array('name'=>'opening_balance','label'=>'Opening Balance','type'=>'number'),
            array('name'=>'description','label'=>'Description','type'=>'textarea'))),
        19037 => array('label'=>'Chart Of Accounts','type'=>'horizontal','fields'=>array(
            array('name'=>'account_code','label'=>'Account Code','type'=>'text'),
            array('name'=>'name','label'=>'Account Name','type'=>'text'),
            array('name'=>'type','label'=>'Type','type'=>'select','options'=>array('Asset','Liability','Equity','Income','Expense')),
            array('name'=>'parent','label'=>'Parent Account','type'=>'text'))),
        19007 => array('label'=>'Journal Entry','type'=>'horizontal','fields'=>array(
            array('name'=>'date','label'=>'Date','type'=>'date'),
            array('name'=>'reference','label'=>'Reference','type'=>'text'),
            array('name'=>'account_debit','label'=>'Debit Account','type'=>'text'),
            array('name'=>'account_credit','label'=>'Credit Account','type'=>'text'),
            array('name'=>'amount','label'=>'Amount','type'=>'number'),
            array('name'=>'narration','label'=>'Narration','type'=>'textarea'))),
        19009 => array('label'=>'Alaab Soo Iibsasho (Purchase)','type'=>'horizontal','fields'=>array(
            array('name'=>'supplier','label'=>'Supplier','type'=>'text'),
            array('name'=>'item','label'=>'Item','type'=>'text'),
            array('name'=>'qty','label'=>'Quantity','type'=>'number'),
            array('name'=>'unit_price','label'=>'Unit Price','type'=>'number'),
            array('name'=>'total','label'=>'Total','type'=>'number'),
            array('name'=>'date','label'=>'Date','type'=>'date'))),
        19017 => array('label'=>'Treasury Evidence','type'=>'horizontal','fields'=>array(
            array('name'=>'date','label'=>'Date','type'=>'date'),
            array('name'=>'amount','label'=>'Amount','type'=>'number'),
            array('name'=>'source','label'=>'Source','type'=>'text'),
            array('name'=>'evidence_note','label'=>'Note','type'=>'textarea'))),
        19025 => array('label'=>'Money Transfer','type'=>'horizontal','fields'=>array(
            array('name'=>'from_account','label'=>'From Account','type'=>'text'),
            array('name'=>'to_account','label'=>'To Account','type'=>'text'),
            array('name'=>'amount','label'=>'Amount','type'=>'number'),
            array('name'=>'date','label'=>'Date','type'=>'date'),
            array('name'=>'note','label'=>'Note','type'=>'textarea'))),
        19010 => array('label'=>'Liiska Alaab Soo iibsashada (Purchase List)','mode'=>'list','source'=>19009),
        19027 => array('label'=>'Funds Transferred','mode'=>'list','source'=>19025),
        19013 => array('label'=>'TRIAL BALANCE','mode'=>'report','source'=>19007),
        19018 => array('label'=>'Journal Report','mode'=>'list','source'=>19007),
        19098 => array('label'=>'Chart Of Accounts','type'=>'horizontal','fields'=>array(
            array('name'=>'account_code','label'=>'Account Code','type'=>'text'),
            array('name'=>'name','label'=>'Account Name','type'=>'text'),
            array('name'=>'type','label'=>'Type','type'=>'select','options'=>array('Asset','Liability','Equity','Income','Expense')),
            array('name'=>'parent','label'=>'Parent Account','type'=>'text'))),
    );

    public function __construct() {
        parent::__construct();
        $this->load->database();
        $this->load->helper('url');
        $this->load->library('session');
        $this->ensure_schema();
    }

    private function ensure_schema() {
        $this->db->query("CREATE TABLE IF NOT EXISTS portal_pages (
            id INT(11) NOT NULL, title VARCHAR(255) NOT NULL DEFAULT '',
            type VARCHAR(40) DEFAULT 'horizontal', fields TEXT, sort INT(11) DEFAULT 0,
            PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8");
        $this->db->query("CREATE TABLE IF NOT EXISTS portal_records (
            id INT(11) NOT NULL AUTO_INCREMENT, page_id INT(11) NOT NULL,
            data LONGTEXT, created_at DATETIME, created_by INT(11) DEFAULT 0,
            PRIMARY KEY (id), KEY page_id (page_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8");
        $this->db->query("CREATE TABLE IF NOT EXISTS portal_logins (
            id INT(11) NOT NULL AUTO_INCREMENT, username VARCHAR(80), pw VARCHAR(120),
            name VARCHAR(120), PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8");
        if ($this->db->count_all('portal_logins') == 0) {
            $this->db->insert('portal_logins', array('username'=>'admin','pw'=>password_hash('admin',PASSWORD_DEFAULT),'name'=>'Administrator'));
        }
        if ($this->db->count_all('portal_pages') == 0) {
            $json = @file_get_contents(FCPATH . 'portal_modules.json');
            $mods = $json ? json_decode($json, true) : array();
            $i = 1;
            foreach ($mods as $m) {
                $id = (int)$m['id'];
                if (isset($this->schemas[$id])) {
                    $s = $this->schemas[$id];
                    $title = $s['label']; $type = $s['type']; $fields = json_encode($s['fields']);
                } else {
                    $title = $m['title'] ?: ('Module '.$id);
                    $type = 'horizontal';
                    $fields = json_encode(array(
                        array('name'=>'name','label'=>'Name','type'=>'text'),
                        array('name'=>'code','label'=>'Code','type'=>'text'),
                        array('name'=>'status','label'=>'Status','type'=>'select','options'=>array('Active','Inactive','Pending')),
                        array('name'=>'date','label'=>'Date','type'=>'date'),
                        array('name'=>'description','label'=>'Description','type'=>'textarea')));
                }
                $this->db->insert('portal_pages', array(
                    'id'=>$id,'title'=>$title,'type'=>$type,'fields'=>$fields,'sort'=>$i++));
            }
        }
    }

    private function auth() {
        return $this->session->userdata('portal_user');
    }

    public function index() {
        if (!$this->auth()) { $this->load->view('portal/login'); return; }
        $pages = $this->db->order_by('sort','asc')->get('portal_pages')->result_array();
        $this->load->view('portal/index', array('pages' => $pages, 'user' => $this->auth()));
    }

    public function login() {
        if ($_POST) {
            $u = $this->input->post('username'); $p = $this->input->post('password');
            $row = $this->db->get_where('portal_logins', array('username'=>$u))->row_array();
            if ($row && password_verify($p, $row['pw'])) {
                $this->session->set_userdata('portal_user', array('id'=>$row['id'],'name'=>$row['name']));
                redirect('portal');
            }
            $this->load->view('portal/login', array('error'=>'Invalid username or password'));
            return;
        }
        $this->load->view('portal/login');
    }

    public function logout() {
        $this->session->unset_userdata('portal_user');
        redirect('portal');
    }

    public function page($id = null) {
        if (!$this->auth()) { redirect('portal'); }
        if (!$id) show_404();
        $page = $this->db->get_where('portal_pages', array('id' => $id))->row_array();
        if (!$page) show_404();
        $mode = ''; $source_records = array(); $report = null;
        $sid = (int)$id;
        if (isset($this->schemas[$sid]) && isset($this->schemas[$sid]['mode'])) {
            $mode = $this->schemas[$sid]['mode'];
            $source = $this->schemas[$sid]['source'];
            $source_records = $this->db->order_by('id','desc')->get_where('portal_records', array('page_id' => $source))->result_array();
            if ($mode == 'report') {
                $bal = array();
                foreach ($source_records as $r) {
                    $obj = array();
                    foreach (json_decode($r['data'], true) ?: array() as $p) { $obj[$p['name']] = $p['value']; }
                    foreach (array('account_debit','account_credit') as $k) {
                        if (!empty($obj[$k]) && isset($obj['amount'])) {
                            $acc = $obj[$k];
                            $bal[$acc] = ($bal[$acc] ?? 0) + (float)$obj['amount'] * ($k=='account_debit'?1:-1);
                        }
                    }
                }
                $report = $bal;
            }
        }
        $records = $this->db->order_by('id','desc')->get_where('portal_records', array('page_id' => $id))->result_array();
        $this->load->view('portal/page', array('page' => $page, 'records' => $records,
            'mode' => $mode, 'source_records' => $source_records, 'report' => $report, 'user'=>$this->auth()));
    }

    public function list($id) {
        if (!$this->auth()) { echo json_encode(array('status'=>0)); return; }
        $rows = $this->db->order_by('id','desc')->get_where('portal_records', array('page_id' => $id))->result_array();
        echo json_encode(array('status' => 1, 'rows' => $rows));
    }

    public function save() {
        if (!$this->auth()) { echo json_encode(array('status' => 0)); return; }
        $id = $this->input->post('page_id');
        $data = $this->input->post('data');
        if (!$id || !$data) { echo json_encode(array('status' => 0)); return; }
        $this->db->insert('portal_records', array(
            'page_id' => $id, 'data' => $data, 'created_at' => date('Y-m-d H:i:s'),
            'created_by' => $this->auth()['id']
        ));
        echo json_encode(array('status' => 1, 'insert_id' => $this->db->insert_id()));
    }

    public function delete($rid) {
        if (!$this->auth()) { echo json_encode(array('status' => 0)); return; }
        $this->db->delete('portal_records', array('id' => $rid));
        echo json_encode(array('status' => 1));
    }

    // One-time: enrich generic module field schemas (call /portal/migrate once).
    public function migrate() {
        if (!$this->auth()) { redirect('portal'); }
        $gen = json_encode(array(
            array('name'=>'name','label'=>'Name','type'=>'text'),
            array('name'=>'description','label'=>'Description','type'=>'textarea')));
        $rich = json_encode(array(
            array('name'=>'name','label'=>'Name','type'=>'text'),
            array('name'=>'code','label'=>'Code','type'=>'text'),
            array('name'=>'status','label'=>'Status','type'=>'select','options'=>array('Active','Inactive','Pending')),
            array('name'=>'date','label'=>'Date','type'=>'date'),
            array('name'=>'description','label'=>'Description','type'=>'textarea')));
        $rows = $this->db->get('portal_pages')->result_array();
        $n = 0;
        foreach ($rows as $r) {
            if ($r['fields'] === $gen) {
                $this->db->where('id', $r['id'])->update('portal_pages', array('fields' => $rich));
                $n++;
            }
        }
        echo "Updated $n generic modules to richer schema.";
    }
}
