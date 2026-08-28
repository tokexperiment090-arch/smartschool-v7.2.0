<?php
/**
 * One-time Somali language activator.
 * Hit this as a logged-in admin: /somali_setup
 * It inserts a 'Somali' row into the languages table (matching the
 * application/language/Somali folder) and enables it in sch_settings.languages.
 */
class Somali_setup extends CI_Controller
{
    public function index()
    {
        $out = array();
        if (!$this->session->userdata('admin')) {
            echo "Access denied: admin login required.";
            return;
        }
        $this->load->database();

        // 1) Insert Somali language row if missing (folder name = 'Somali')
        $exists = $this->db->get_where('languages', array('language' => 'Somali'))->row();
        if (!$exists) {
            $this->db->insert('languages', array(
                'id'          => 91,
                'language'    => 'Somali',
                'short_code'  => 'so',
                'country_code'=> 'so',
                'is_rtl'      => 0,
                'is_deleted'  => 'no',
                'is_active'   => 'yes',
                'created_at'  => date('Y-m-d H:i:s'),
                'updated_at'  => date('Y-m-d H:i:s'),
            ));
            $out[] = "Inserted Somali language row (id 91).";
        } else {
            // ensure active
            $this->db->where('id', $exists->id)->update('languages', array('is_active' => 'yes', 'is_deleted' => 'no'));
            $out[] = "Somali language row already present (id " . $exists->id . "), set active.";
            $somali_id = $exists->id;
        }
        if (!isset($somali_id)) {
            $somali_id = 91;
        }

        // 2) Enable Somali in sch_settings.languages JSON
        $row = $this->db->select('languages')->from('sch_settings')->where('id', 1)->get()->row();
        $ids = array();
        if ($row && !empty($row->languages)) {
            $dec = json_decode($row->languages, true);
            if (is_array($dec)) {
                $ids = $dec;
            }
        }
        if (!in_array($somali_id, $ids)) {
            $ids[] = $somali_id;
            $this->db->where('id', 1)->update('sch_settings', array('languages' => json_encode($ids)));
            $out[] = "Enabled Somali (id $somali_id) in sch_settings.languages = " . json_encode($ids) . ".";
        } else {
            $out[] = "Somali already enabled in sch_settings.languages.";
        }

        echo implode("<br>\n", $out);
        echo "<br>\nDONE. Somali is now registered and enabled. You can remove this controller afterwards.";
    }
}
