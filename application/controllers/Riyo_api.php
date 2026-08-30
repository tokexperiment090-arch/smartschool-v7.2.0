<?php
/**
 * Riyo Mobile App JSON API (students/parents).
 * Endpoints (all return JSON):
 *   /riyo_api/setup                -> create token table (idempotent)
 *   /riyo_api/login                -> POST username,password -> {token, student}
 *   /riyo_api/profile   ?token=... -> student profile + class/section
 *   /riyo_api/attendance?token=... -> attendance list (month optional)
 *   /riyo_api/fees       ?token=... -> fee summary (expected/paid/balance)
 *   /riyo_api/notices    ?token=... -> school notices
 *   /riyo_api/dashboard  ?token=... -> quick summary
 * Auth: bearer-style token stored in riyo_api_tokens (user_id, expires_at).
 */
class Riyo_api extends CI_Controller
{
    private $SECRET = 'riyo_app_2025'; // app<->server shared secret (change in production)
    private $TOKEN_TTL = 86400;        // 24h

    public function __construct()
    {
        parent::__construct();
        $this->load->database();
        $this->load->library('enc_lib');
        $this->setup_table();
    }

    private function setup_table()
    {
        if (!$this->db->table_exists('riyo_api_tokens')) {
            $this->db->query("CREATE TABLE riyo_api_tokens (
                id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                api_token VARCHAR(80) NOT NULL,
                expires_at DATETIME NOT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                KEY (api_token)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
        }
    }

    private function json($data, $code = 200)
    {
        $this->output
            ->set_status_header($code)
            ->set_content_type('application/json')
            ->set_output(json_encode($data, JSON_UNESCAPED_UNICODE));
    }

    private function auth()
    {
        $token = $this->input->get_post('token') ?: $this->input->get_request_header('Authorization', TRUE);
        $token = preg_replace('/^Bearer\s+/i', '', (string)$token);
        if (!$token) return false;
        $row = $this->db->get_where('riyo_api_tokens', array('api_token' => $token))->row();
        if (!$row) return false;
        if (strtotime($row->expires_at) < time()) { $this->db->delete('riyo_api_tokens', array('id' => $row->id)); return false; }
        return (int)$row->user_id;
    }

    private function student_by_user($user_id)
    {
        // users.user_id references students.id for role=parent/student
        return $this->db->get_where('students', array('id' => $user_id))->row();
    }

    public function setup()
    {
        $this->json(array('ok' => true, 'table' => $this->db->table_exists('riyo_api_tokens')));
    }

    public function login()
    {
        $username = $this->input->post('username');
        $password = $this->input->post('password');
        if (!$username || !$password) { return $this->json(array('status' => 'error', 'message' => 'username and password required'), 400); }

        $this->db->where('username', $username);
        $user = $this->db->get('users')->row();
        if (!$user) { return $this->json(array('status' => 'error', 'message' => 'Invalid credentials'), 401); }
        if ($user->role != 'student' && $user->role != 'parent') {
            return $this->json(array('status' => 'error', 'message' => 'This app is for students/parents only'), 403);
        }
        // SmartSchool stores users.password in plaintext (verified against User_model::checkLogin).
        if ($user->password !== $password) {
            return $this->json(array('status' => 'error', 'message' => 'Invalid credentials'), 401);
        }

        $student = $this->student_by_user($user->user_id);
        if (!$student) { return $this->json(array('status' => 'error', 'message' => 'No student linked to this account'), 404); }

        // issue token
        $this->db->delete('riyo_api_tokens', array('user_id' => $user->user_id));
        $token = bin2hex(random_bytes(32));
        $this->db->insert('riyo_api_tokens', array(
            'user_id' => $user->user_id,
            'api_token' => $token,
            'expires_at' => date('Y-m-d H:i:s', time() + $this->TOKEN_TTL),
        ));
        $this->json(array(
            'status' => 'success',
            'token' => $token,
            'expires_at' => date('Y-m-d H:i:s', time() + $this->TOKEN_TTL),
            'student' => $this->public_student($student),
        ));
    }

    private function public_student($s)
    {
        $ss = $this->db->get_where('student_session', array('student_id' => $s->id, 'is_active' => 'yes'))->row();
        $class = $section = '';
        if ($ss) {
            $c = $this->db->get_where('classes', array('id' => $ss->class_id))->row();
            $sec = $this->db->get_where('sections', array('id' => $ss->section_id))->row();
            $class = $c ? $c->class : '';
            $section = $sec ? $sec->section : '';
        }
        return array(
            'admission_no' => $s->admission_no,
            'firstname' => $s->firstname,
            'lastname' => $s->lastname,
            'gender' => $s->gender,
            'class' => $class,
            'section' => $section,
        );
    }

    public function profile()
    {
        $uid = $this->auth();
        if (!$uid) return $this->json(array('status' => 'error', 'message' => 'unauthorized'), 401);
        $s = $this->student_by_user($uid);
        if (!$s) return $this->json(array('status' => 'error', 'message' => 'not found'), 404);
        $this->json(array('status' => 'success', 'student' => $this->public_student($s)));
    }

    public function attendance()
    {
        $uid = $this->auth();
        if (!$uid) return $this->json(array('status' => 'error', 'message' => 'unauthorized'), 401);
        $s = $this->student_by_user($uid);
        if (!$s) return $this->json(array('status' => 'error', 'message' => 'not found'), 404);
        $ss = $this->db->get_where('student_session', array('student_id' => $s->id, 'is_active' => 'yes'))->row();
        if (!$ss) return $this->json(array('status' => 'success', 'attendance' => array()));
        $month = $this->input->get('month'); // YYYY-MM
        $this->db->select('sa.date, sa.remark, at.type as status');
        $this->db->from('student_attendences sa');
        $this->db->join('attendence_type at', 'at.id = sa.attendence_type_id', 'left');
        $this->db->where('sa.student_session_id', $ss->id);
        if ($month) $this->db->like('sa.date', $month, 'after');
        $this->db->order_by('sa.date', 'DESC');
        $rows = $this->db->get()->result_array();
        $this->json(array('status' => 'success', 'attendance' => $rows));
    }

    public function fees()
    {
        $uid = $this->auth();
        if (!$uid) return $this->json(array('status' => 'error', 'message' => 'unauthorized'), 401);
        $s = $this->student_by_user($uid);
        if (!$s) return $this->json(array('status' => 'error', 'message' => 'not found'), 404);
        $ss = $this->db->get_where('student_session', array('student_id' => $s->id, 'is_active' => 'yes'))->row();
        if (!$ss) return $this->json(array('status' => 'success', 'fees' => array('expected' => 0, 'paid' => 0, 'balance' => 0)));
        // expected = sum of feemasters for class
        $this->db->select_sum('amount', 'expected');
        $this->db->where('class_id', $ss->class_id);
        $exp = $this->db->get('feemasters')->row();
        $expected = $exp ? (float)$exp->expected : 0;
        // paid = sum of student_fees deposits for this student session
        $this->db->select_sum('amount', 'paid');
        $this->db->where('student_session_id', $ss->id);
        $pay = $this->db->get('student_fees')->row();
        $paid = $pay ? (float)$pay->paid : 0;
        $this->json(array(
            'status' => 'success',
            'fees' => array(
                'expected' => $expected,
                'paid' => $paid,
                'balance' => max(0, $expected - $paid),
            ),
        ));
    }

    public function notices()
    {
        $uid = $this->auth();
        if (!$uid) return $this->json(array('status' => 'error', 'message' => 'unauthorized'), 401);
        $this->db->select('title, message, publish_date, date');
        $this->db->from('send_notification');
        $this->db->where("visible_student IN ('Yes','yes','YES','1','true')", null, false);
        $this->db->order_by('publish_date', 'DESC');
        $this->db->limit(20);
        $rows = $this->db->get()->result_array();
        $out = array();
        foreach ($rows as $r) {
            $out[] = array(
                'title' => $r['title'],
                'message' => $r['message'],
                'date' => $r['publish_date'] ?: $r['date'],
            );
        }
        $this->json(array('status' => 'success', 'notices' => $out));
    }

    public function examresults()
    {
        $uid = $this->auth();
        if (!$uid) return $this->json(array('status' => 'error', 'message' => 'unauthorized'), 401);
        $s = $this->student_by_user($uid);
        if (!$s) return $this->json(array('status' => 'error', 'message' => 'not found'), 404);

        // All student sessions (current AND old classes) so past exam results show too.
        $this->db->select('ss.id as ssid, ss.session_id, ses.session as session_name, c.class as class_name, sec.section as section_name');
        $this->db->from('student_session ss');
        $this->db->join('sessions ses', 'ses.id = ss.session_id', 'left');
        $this->db->join('classes c', 'c.id = ss.class_id', 'left');
        $this->db->join('sections sec', 'sec.id = ss.section_id', 'left');
        $this->db->where('ss.student_id', $s->id);
        $this->db->order_by('ss.session_id', 'DESC');
        $sessions = $this->db->get()->result_array();

        $out = array();
        foreach ($sessions as $sess) {
            $sid = $sess['ssid'];
            // published exam group exams linked to this student_session
            $this->db->select('egcbse.id as exam_student_id, egcbe.id as egcbe_id, eg.id as exam_group_id, eg.name as exam_group_name');
            $this->db->from('exam_group_class_batch_exam_students egcbse');
            $this->db->join('exam_group_class_batch_exams egcbe', 'egcbe.id = egcbse.exam_group_class_batch_exam_id');
            $this->db->join('exam_groups eg', 'eg.id = egcbe.exam_group_id');
            $this->db->where('egcbse.student_session_id', $sid);
            $this->db->where('egcbe.is_publish', 1);
            $exams = $this->db->get()->result_array();

            $groups = array();
            foreach ($exams as $e) {
                $this->db->select('egcbes.subject_id, s.name as subject, egcbes.max_marks, r.get_marks, r.attendence, r.note');
                $this->db->from('exam_group_class_batch_exam_subjects egcbes');
                $this->db->join('subjects s', 's.id = egcbes.subject_id', 'left');
                $this->db->join('exam_group_exam_results r', 'r.exam_group_class_batch_exam_subject_id = egcbes.id AND r.exam_group_class_batch_exam_student_id = ' . (int)$e['exam_student_id'], 'left');
                $this->db->where('egcbes.exam_group_class_batch_exams_id', $e['egcbe_id']);
                $subjects = $this->db->get()->result_array();

                $total_max = 0; $total_get = 0; $has_marks = false;
                foreach ($subjects as &$sub) {
                    $sub['max_marks'] = is_numeric($sub['max_marks']) ? (float)$sub['max_marks'] : null;
                    $sub['get_marks'] = is_numeric($sub['get_marks']) ? (float)$sub['get_marks'] : null;
                    if ($sub['max_marks'] !== null) $total_max += $sub['max_marks'];
                    if ($sub['get_marks'] !== null) { $total_get += $sub['get_marks']; $has_marks = true; }
                }
                $pct = ($has_marks && $total_max > 0) ? round($total_get / $total_max * 100, 1) : null;
                $groups[] = array(
                    'exam_group' => $e['exam_group_name'],
                    'subjects' => $subjects,
                    'total_max' => $total_max,
                    'total_get' => $has_marks ? $total_get : null,
                    'percentage' => $pct === null ? null : (string)$pct, // clean "80.4"
                    'grade' => $pct === null ? null : $this->grade_for($pct),
                );
            }

            if (!empty($groups)) {
                $out[] = array(
                    'session' => $sess['session_name'] ?: 'Session',
                    'class' => trim(($sess['class_name'] ?? '') . ' ' . ($sess['section_name'] ?? '')),
                    'exam_groups' => $groups,
                );
            }
        }
        $this->json(array('status' => 'success', 'sessions' => $out));
    }

    private function grade_for($pct)
    {
        if ($pct >= 90) return 'A+';
        if ($pct >= 80) return 'A';
        if ($pct >= 70) return 'B';
        if ($pct >= 60) return 'C';
        if ($pct >= 50) return 'D';
        return 'F';
    }

    public function dashboard()
    {
        $uid = $this->auth();
        if (!$uid) return $this->json(array('status' => 'error', 'message' => 'unauthorized'), 401);
        $s = $this->student_by_user($uid);
        if (!$s) return $this->json(array('status' => 'error', 'message' => 'not found'), 404);
        $ss = $this->db->get_where('student_session', array('student_id' => $s->id, 'is_active' => 'yes'))->row();
        $att_count = 0;
        if ($ss) {
            $this->db->where('student_session_id', $ss->id);
            $att_count = $this->db->count_all_results('student_attendences');
        }
        $this->json(array(
            'status' => 'success',
            'student' => $this->public_student($s),
            'attendance_records' => $att_count,
        ));
    }
}
