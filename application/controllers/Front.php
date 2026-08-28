<?php
// Frontend (public site) for Riyo — clones Mustaqbal's public landing page.
// Mirrors: hero + special-needs center intro + Customer Portal button + inquiry form.
// Working backend: inquiries saved to front_inquiries table.
defined('BASEPATH') OR exit('No direct script access allowed');

class Front extends CI_Controller {

    public function __construct() {
        parent::__construct();
        $this->load->database();
        $this->load->helper('url');
        $this->load->library('session');
        $this->db->query("CREATE TABLE IF NOT EXISTS front_inquiries (
            id INT(11) NOT NULL AUTO_INCREMENT, name VARCHAR(120), email VARCHAR(160),
            phone VARCHAR(40), message TEXT, created_at DATETIME, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8");
    }

    public function index() {
        $data['title'] = 'Riyo Center For Special Needs';
        $this->load->view('front/index', $data);
    }

    public function inquiry() {
        if ($_POST) {
            $this->db->insert('front_inquiries', array(
                'name' => $this->input->post('name'),
                'email' => $this->input->post('email'),
                'phone' => $this->input->post('phone'),
                'message' => $this->input->post('message'),
                'created_at' => date('Y-m-d H:i:s')
            ));
            $this->session->set_flashdata('ok', 'Thank you — we received your inquiry.');
            redirect('front');
        }
        $this->index();
    }
}
