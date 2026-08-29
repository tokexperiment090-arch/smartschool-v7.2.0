<?php
error_reporting(E_ALL); ini_set('display_errors', 1);
/**
 * Generate full realistic test data for Riyo (students, teachers, classes,
 * sections, parents, subjects, exams, fees, attendance).
 * Run once as logged-in admin: /testdata
 * Idempotent: checks existing counts before inserting.
 */
class Testdata extends CI_Controller
{
    private $DEF = 'Test';          // default text for NOT NULL varchar fields
    private $DEFDATE = '2000-01-01'; // default date

    public function index()
    {
        if (!$this->session->userdata('admin')) { echo "admin login required"; return; }
        $this->load->database();
        $out = array();

        // ensure test logins use plaintext passwords (SmartSchool stores users.password in plaintext)
        $this->db->query("UPDATE users SET password='parent123' WHERE username LIKE 'RYY%'");
        $this->db->query("UPDATE users SET password='teacher123' WHERE username LIKE 'TCH%'");
        $this->db->query("UPDATE staff SET password='teacher123' WHERE employee_id LIKE 'TCH%'");

        // ---- session ----
        $sess = $this->db->where('is_active','yes')->get('sessions')->row();
        if (!$sess) {
            $this->db->insert('sessions', array('session'=>'2025-26','is_active'=>'yes'));
            $sess_id = $this->db->insert_id(); $out[] = "created session 2025-26 (id $sess_id)";
        } else { $sess_id = $sess->id; $out[] = "using session id $sess_id"; }

        // ---- classes ----
        $classes = array('Grade 1','Grade 2','Grade 3');
        $class_ids = array();
        foreach ($classes as $c) {
            $row = $this->db->get_where('classes', array('class'=>$c))->row();
            if (!$row) { $this->db->insert('classes', array('class'=>$c,'is_active'=>'yes')); $id=$this->db->insert_id(); $out[]="class $c (id $id)"; }
            else { $id=$row->id; }
            $class_ids[$c] = $id;
        }

        // ---- sections ----
        $sections = array('A','B');
        $section_ids = array();
        foreach ($sections as $s) {
            $row = $this->db->get_where('sections', array('section'=>$s))->row();
            if (!$row) { $this->db->insert('sections', array('section'=>$s,'is_active'=>'yes')); $id=$this->db->insert_id(); $out[]="section $s (id $id)"; }
            else { $id=$row->id; }
            $section_ids[$s] = $id;
        }

        // ---- class_sections ----
        $cs_map = array();
        foreach ($class_ids as $c) {
            foreach ($section_ids as $s) {
                $row = $this->db->get_where('class_sections', array('class_id'=>$c,'section_id'=>$s))->row();
                if (!$row) { $this->db->insert('class_sections', array('class_id'=>$c,'section_id'=>$s,'is_active'=>'yes')); $id=$this->db->insert_id(); }
                else { $id=$row->id; }
                $cs_map[$id] = array('class_id'=>$c,'section_id'=>$s);
            }
        }
        $out[] = "class_sections: ".count($cs_map);

        // ---- subjects (global) ----
        $subjects = array('Mathematics'=>'MATH','English'=>'ENG','Science'=>'SCI','Somali'=>'SOM','Social Studies'=>'SOS');
        foreach ($subjects as $nm=>$code) {
            $row = $this->db->get_where('subjects', array('name'=>$nm))->row();
            if (!$row) { $this->db->insert('subjects', array('name'=>$nm,'code'=>$code,'is_active'=>'yes')); $out[]="subject $nm"; }
        }

        // ---- teachers (staff) with full NOT NULL coverage ----
        $teachers = array('Ahmed Ali','Fatima Hassan','Mohamed Nur','Amina Said','Abdirahman Omar');
        $existing_staff = $this->db->count_all('staff');
        if ($existing_staff < 6) {
            $ti = 1;
            foreach ($teachers as $nm) {
                $emp = 'TCH'.str_pad($ti,3,'0');
                $row = $this->db->get_where('staff', array('employee_id'=>$emp))->row();
                if (!$row) {
                    $this->db->cache_off();
                    $sd = array(
                        'employee_id'=>$emp,'lang_id'=>95,'currency_id'=>0,'department'=>null,'designation'=>null,
                        'qualification'=>$this->DEF,'work_exp'=>$this->DEF,'name'=>$nm,'surname'=>$this->DEF,
                        'father_name'=>$this->DEF,'mother_name'=>$this->DEF,'contact_no'=>'06100000'.$ti,
                        'emergency_contact_no'=>'06100000'.$ti,'email'=>strtolower(str_replace(' ','', $nm)).'@riyo.edu',
                        'dob'=>$this->DEFDATE,'marital_status'=>'Single','date_of_joining'=>date('Y-m-d'),
                        'local_address'=>$this->DEF,'permanent_address'=>$this->DEF,'note'=>$this->DEF,'image'=>$this->DEF,
                        'password'=>'parent123',
                        'account_title'=>$this->DEF,'bank_account_no'=>$this->DEF,'bank_name'=>$this->DEF,
                        'ifsc_code'=>$this->DEF,'bank_branch'=>$this->DEF,'payscale'=>$this->DEF,'epf_no'=>$this->DEF,
                        'contract_type'=>$this->DEF,'shift'=>$this->DEF,'location'=>$this->DEF,'facebook'=>$this->DEF,
                        'twitter'=>$this->DEF,'linkedin'=>$this->DEF,'instagram'=>$this->DEF,'resume'=>$this->DEF,
                        'joining_letter'=>$this->DEF,'resignation_letter'=>$this->DEF,'other_document_name'=>$this->DEF,
                        'other_document_file'=>$this->DEF,'user_id'=>$ti,'is_active'=>1,'verification_code'=>$this->DEF,
                    );
                    $cols = array_keys($sd);
                    $vals = array();
                    foreach (array_values($sd) as $v) {
                        $vals[] = ($v === null) ? 'NULL' : $this->db->escape($v);
                    }
                    $sql = "INSERT INTO staff (`".implode('`,`',$cols)."`) VALUES (".implode(',',$vals).")";
                    $q = $this->db->query($sql);
                    if (!$q) { $e=$this->db->error(); $out[] = "RAW STAFF FAIL $emp: ".$e['code'].' '.$e['message']; }
                    else {
                        $emp_esc = $this->db->escape($emp);
                        $chk = $this->db->query("SELECT id FROM staff WHERE employee_id=$emp_esc")->row();
                        if (!$chk) { $e=$this->db->error(); $out[] = "RAW STAFF inserted but missing (err=".$e['code']." ".$e['message'].")"; }
                        else {
                            $staff_id = $chk->id;
                            $this->db->query("INSERT INTO staff_roles (role_id,staff_id,is_active) VALUES (2,$staff_id,1)");
                            $this->db->query("INSERT INTO users (user_id,username,password,role,lang_id,is_active) VALUES ($staff_id,$emp_esc,'teacher123','teacher',95,'yes')");
                            $out[] = "teacher $emp $nm (id $staff_id)";
                        }
                    }
                }
                $ti++;
            }
        } else { $out[] = "staff already present ($existing_staff), skipped"; }

        // ---- students + parents ----
        $first = array('Ali','Sahra','Hassan','Maryam','Omar','Fadumo','Ibrahim','Halima','Yusuf','Khadra','Ahmed','Ayan','Mustafa','Nadia','Bilan');
        $last  = array('Mohamed','Ali','Nur','Said','Omar','Hassan','Ahmed','Farah','Abdullahi','Ismail');
        $cur = $this->db->count_all('students');
        // Clean-slate the RYY demo accounts so student_session.student_id is always correct.
        $rrows = $this->db->query("SELECT id FROM students WHERE admission_no LIKE 'RYY%'")->result();
        foreach ($rrows as $r) {
            $this->db->query("DELETE FROM student_session WHERE student_id=".(int)$r->id);
            $this->db->query("DELETE FROM users WHERE user_id=".(int)$r->id);
            $this->db->query("DELETE FROM students WHERE id=".(int)$r->id);
        }
        $cur = 0;
        if ($cur < 5) {
            $n = 0;
            foreach ($cs_map as $cs => $csrow) {
                $per = ($n % 2 == 0) ? 3 : 2;
                for ($k=0; $k<$per && $n<count($first); $k++) {
                    $fn = $first[$n]; $ln = $last[($n*3)%count($last)];
                    $adm = 'RYY'.str_pad($n+1,4,'0');
                    $row = $this->db->get_where('students', array('admission_no'=>$adm))->row();
                    if (!$row) {
                        $student_data = array(
                            'parent_id'=>0,'admission_no'=>$adm,'roll_no'=>($n+1),'admission_date'=>date('Y-m-d'),
                            'firstname'=>$fn,'middlename'=>'','lastname'=>$ln,'rte'=>'No','image'=>$this->DEF,
                            'mobileno'=>'061'.str_pad($n+1,7,'0'),'email'=>strtolower($fn).'@riyo.edu',
                            'state'=>$this->DEF,'city'=>$this->DEF,'pincode'=>'12345','religion'=>$this->DEF,'cast'=>$this->DEF,
                            'dob'=>$this->DEFDATE,'gender'=>($n%2?'Female':'Male'),'current_address'=>$this->DEF,
                            'permanent_address'=>$this->DEF,'category_id'=>1,'blood_group'=>'O+','hostel_room_id'=>0,
                            'guardian_is'=>'Father','father_name'=>$ln,'father_phone'=>'061'.str_pad($n+1,7,'0'),
                            'father_occupation'=>$this->DEF,'mother_name'=>$this->DEF,'mother_phone'=>$this->DEF,
                            'mother_occupation'=>$this->DEF,'guardian_name'=>'Parent of '.$fn,'guardian_relation'=>'Father',
                            'guardian_phone'=>'061'.str_pad($n+1,7,'0'),'guardian_occupation'=>$this->DEF,
                            'guardian_address'=>$this->DEF,'guardian_email'=>strtolower($fn).'@riyo.edu',
                            'father_pic'=>$this->DEF,'mother_pic'=>$this->DEF,'guardian_pic'=>$this->DEF,
                            'is_active'=>'yes','height'=>'1.2','weight'=>'25','dis_reason'=>0,'dis_note'=>$this->DEF,
                            'about'=>$this->DEF,
                        );
                        $this->db->insert('students', $student_data);
                        $stu_id = $this->db->insert_id();
                        $this->db->insert('users', array('user_id'=>$stu_id,'username'=>$adm,'password'=>'parent123','role'=>'parent','lang_id'=>95,'is_active'=>'yes'));
                        $par_id = $this->db->insert_id();
                        $this->db->where('id',$stu_id)->update('students', array('parent_id'=>$par_id));
                        $this->db->insert('student_session', array(
                            'session_id'=>$sess_id,'student_id'=>$stu_id,'class_id'=>$csrow['class_id'],
                            'section_id'=>$csrow['section_id'],'is_active'=>'yes',
                        ));
                        $out[] = "student $adm $fn $ln (cs $cs)";
                    }
                    $n++;
                }
                if ($n>=count($first)) break;
            }
        } else { $out[] = "students already present ($cur), skipped"; }

        // ---- sample student attendance ----
        $stu = $this->db->get('students')->result();
        $att = 0; $today = date('Y-m-d');
        foreach ($stu as $s) {
            $ss = $this->db->get_where('student_session', array('student_id'=>$s->id))->row();
            if ($ss) {
                $chk = $this->db->get_where('student_attendences', array('student_session_id'=>$ss->id,'date'=>$today))->row();
                if (!$chk) {
                    $this->db->insert('student_attendences', array('student_session_id'=>$ss->id,'attendence_type_id'=>1,'date'=>$today,'remark'=>'Present','biometric_attendence'=>0,'is_active'=>'yes'));
                    $att++;
                }
            }
        }
        $out[] = "sample student attendance rows added: $att";

        // ---- fees ----
        $ft = $this->db->get_where('feetype', array('type'=>'Tuition Fee'))->row();
        if (!$ft) { $this->db->insert('feetype', array('type'=>'Tuition Fee','is_active'=>'yes')); $ftid=$this->db->insert_id(); $out[]="feetype Tuition Fee (id $ftid)"; }
        else { $ftid=$ft->id; }
        foreach ($class_ids as $c) {
            $fm = $this->db->get_where('feemasters', array('class_id'=>$c,'feetype_id'=>$ftid))->row();
            if (!$fm) { $this->db->insert('feemasters', array('session_id'=>$sess_id,'feetype_id'=>$ftid,'class_id'=>$c,'amount'=>150,'is_active'=>'yes')); $out[]="feemaster for class $c"; }
        }
        $out[] = "fee masters created";

        // ---- exam groups + results (exam_group_* schema) ----
        $eg = $this->db->get_where('exam_groups', array('name' => 'Mid Term 2025'))->row();
        if (!$eg) {
            $this->db->insert('exam_groups', array('name'=>'Mid Term 2025','exam_type'=>'UT','is_active'=>1));
            $eg_id = $this->db->insert_id(); $out[] = "exam_group Mid Term 2025 (id $eg_id)";
        } else { $eg_id = $eg->id; }

        // one published exam per class so every student has a result
        foreach ($class_ids as $cid) {
            $row = $this->db->get_where('exam_group_class_batch_exams', array('exam_group_id'=>$eg_id,'exam'=>('MidTerm-'.$cid)))->row();
            if (!$row) {
                $this->db->insert('exam_group_class_batch_exams', array(
                    'exam'=>('MidTerm-'.$cid),'passing_percentage'=>35,'session_id'=>$sess_id,
                    'date_from'=>date('Y-m-d'),'date_to'=>date('Y-m-d', strtotime('+7 days')),
                    'exam_group_id'=>$eg_id,'is_publish'=>1,'is_active'=>1));
                $egcbe_id = $this->db->insert_id();
            } else { $egcbe_id = $row->id; }

            // subjects for this exam
            $subj_ids = $this->db->select('id')->get('subjects')->result_array();
            $subj_ids = array_column($subj_ids, 'id');
            $subj_link = array();
            foreach ($subj_ids as $sid) {
                $chk = $this->db->get_where('exam_group_class_batch_exam_subjects', array('exam_group_class_batch_exams_id'=>$egcbe_id,'subject_id'=>$sid))->row();
                if (!$chk) {
                    $this->db->insert('exam_group_class_batch_exam_subjects', array(
                        'exam_group_class_batch_exams_id'=>$egcbe_id,'subject_id'=>$sid,
                        'date_from'=>date('Y-m-d'),'time_from'=>'09:00:00','duration'=>'2','max_marks'=>100,'min_marks'=>35,'credit_hours'=>1,'is_active'=>1));
                    $subj_link[$sid] = $this->db->insert_id();
                } else { $subj_link[$sid] = $chk->id; }
            }

            // link every student_session of this class to the exam
            $this->db->select('id, student_id'); $this->db->where('class_id', $cid); $this->db->where('is_active','yes');
            $ss_list = $this->db->get('student_session')->result();
            foreach ($ss_list as $ssr) {
                $chk = $this->db->get_where('exam_group_class_batch_exam_students', array('exam_group_class_batch_exam_id'=>$egcbe_id,'student_session_id'=>$ssr->id))->row();
                if (!$chk) {
                    $max = $this->db->select_max('id')->get('exam_group_class_batch_exam_students')->row()->id;
                    $new_id = ($max ? (int)$max : 0) + 1;
                    $this->db->insert('exam_group_class_batch_exam_students', array(
                        'id'=>$new_id,
                        'exam_group_class_batch_exam_id'=>$egcbe_id,'student_id'=>$ssr->student_id,
                        'student_session_id'=>$ssr->id,'roll_no'=>$ssr->id,'is_active'=>1));
                    $e = $this->db->error();
                    if ($this->db->affected_rows() == 0 || $e['code'] != 0) { $out[]="EXAMSTUD FAIL: ".$e['code'].' '.$e['message']; }
                    else { $out[]="EGCBES ok stu=".$ssr->student_id." ss=".$ssr->id." id=".$new_id; }
                    $egcbest_id = $new_id;
                    // insert a result row per subject
                    foreach ($subj_link as $sid => $link_id) {
                        $mark = rand(55, 98);
                        $q = $this->db->insert('exam_group_exam_results', array(
                            'exam_group_class_batch_exam_student_id'=>$egcbest_id,
                            'exam_group_class_batch_exam_subject_id'=>$link_id,
                            'attendence'=>'Present','get_marks'=>$mark,'is_active'=>1));
                        if (!$q) { $e=$this->db->error(); $out[]="RESULT FAIL: ".$e['code'].' '.$e['message']; }
                    }
                }
            }
        }
        $out[] = "exam groups + results generated";

        echo implode("<br>\n", $out);
        echo "<br>\nDONE. Test data generated.";
    }

    public function verify()
    {
        if (!$this->session->userdata('admin')) { echo "admin login required"; return; }
        $this->load->database();
        $students = $this->db->count_all('students');
        $with_ss  = $this->db->query("SELECT COUNT(*) c FROM students s WHERE EXISTS(SELECT 1 FROM student_session ss WHERE ss.student_id=s.id)")->row()->c;
        $staff    = $this->db->count_all('staff');
        $rows = $this->db->select('employee_id,name')->get('staff')->result();
        $emps = array_map(function($r){ return $r->employee_id.'/'.$r->name; }, $rows);
        $classes  = $this->db->count_all('classes');
        $sections = $this->db->count_all('sections');
        $cs       = $this->db->count_all('class_sections');
        $att      = $this->db->count_all('student_attendences');
        $fm       = $this->db->count_all('feemasters');
        echo "students(total)=$students  with_session=$with_ss<br>\n";
        echo "staff=$staff  [".implode(', ', $emps)."]<br>\n";
        echo "student_attendences=$att  feemasters=$fm<br>\n";
        $u = $this->db->query("SELECT username,role FROM users WHERE username LIKE 'RYY%' OR username LIKE 'TCH%' LIMIT 20")->result();
        echo "test users: ".implode(', ', array_map(function($r){return $r->username.'/'.$r->role;}, $u))."<br>\n";
        echo "Integrity: ".($students==$with_ss ? "OK (all students have a session)" : "GAP (some students missing session!)");
    }
}
