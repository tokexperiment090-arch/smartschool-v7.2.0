<?php
/**
 * Somali language activator (idempotent).
 * Hit as logged-in admin: /somali_setup
 *  - ensures a 'Somali' row exists in the languages table (folder = 'Somali')
 *  - enables it in sch_settings.languages
 *  - (does NOT force it as the default school language; that can break the
 *    admin login if done via GET. Use the switcher to pick Somali.)
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

        $exists = $this->db->get_where('languages', array('language' => 'Somali'))->row();
        if (!$exists) {
            // also catch a lowercase 'somali' row that may already exist (wrong folder case)
            $lower = $this->db->get_where('languages', array('language' => 'somali'))->row();
            if ($lower) {
                $this->db->where('id', $lower->id)->update('languages', array(
                    'language'    => 'Somali',
                    'short_code'  => 'so',
                    'country_code'=> 'so',
                    'is_rtl'      => 0,
                    'is_deleted'  => 'no',
                    'is_active'   => 'yes',
                ));
                $somali_id = $lower->id;
                $out[] = "Found lowercase 'somali' row (id $somali_id); corrected to 'Somali' to match the language folder.";
            } else {
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
                $somali_id = 91;
                $out[] = "Inserted Somali language row (id 91).";
            }
        } else {
            // ensure correct folder-matching case 'Somali' (MySQL match is case-insensitive,
            // so force-capitalize to be safe for case-sensitive filesystems)
            $this->db->where('id', $exists->id)->update('languages', array('language' => 'Somali', 'is_active' => 'yes', 'is_deleted' => 'no'));
            $somali_id = $exists->id;
            $out[] = "Somali row present (id $somali_id), forced case 'Somali' + active.";
        }

        $row = $this->db->select('languages')->from('sch_settings')->where('id', 1)->get()->row();
        $ids = array();
        if ($row && !empty($row->languages)) {
            $dec = json_decode($row->languages, true);
            if (is_array($dec)) $ids = $dec;
        }
        if (!in_array($somali_id, $ids)) {
            $ids[] = $somali_id;
            $this->db->where('id', 1)->update('sch_settings', array('languages' => json_encode($ids)));
            $out[] = "Enabled Somali (id $somali_id) in sch_settings.languages = " . json_encode($ids) . ".";
        } else {
            $out[] = "Somali already enabled in sch_settings.languages.";
        }

        // 3) Set the logged-in admin's staff record language to Somali so the
        //    session actually loads the Somali folder (staff.lang_id joins languages.id).
        $session = $this->session->userdata('admin');
        if (!empty($session['id'])) {
            $this->db->where('id', $session['id'])->update('staff', array('lang_id' => $somali_id));
            $out[] = "Set admin staff.lang_id = $somali_id (Somali) so the session renders Somali.";
        }

        echo implode("<br>\n", $out);
        echo "<br>\nDONE. Somali is registered + enabled. Pick it from the top-right language switcher.";
    }
}
