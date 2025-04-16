#!/bin/bash
VERSION='Simple Performance Tool V 0.3'

## global value
RunTimePerTest=1200
log_interval=500
#
rand_ramp_time=300

function SetFIOWorkload(){
    if [ $1 == 'mixed' ];then
        ## 
        logging "Mixed IO workload set."
        RandBS=(512 4k 8k 16k 1024k)
        RandQD=(32 64 128)
        RandJobs=(4 8)
        RandRWMixRead=(100 75 70 0)
        seqBS=(128k 1024k)
        seqQD=(32 128)
        seqJobs=(1)
        LatBS=(512 4k 8k)
        LatQD=(1)
        LatJobs=(1)
    else
        logging "Simple IO workload set."
        RandBS=(4k)
        RandQD=(128)
        RandJobs=(8)
        RandRWMixRead=(100 0)
        seqBS=(128k)
        seqQD=(32)
        seqJobs=(1)
        LatBS=(4k)
        LatQD=(1)
        LatJobs=(1)
    fi
}

#####
# This Function Show tool help message
FunEchoHelp(){
    echo "-h       Show this help info"
    echo "-v       Tool version"
    echo "-d       Your target device that will be tested, example -d sdb,sdc"
    echo "-t       Test workload type, simple|mixed"
    echo "-s       Test work suite split by comma(like iops,tp), {iops,tp,lat}"
    echo "-p       Disable Preconditon before test case"
}

# function to do 128k seq write x2
function logging(){
    t=$(date "+%Y-%m-%d %H:%M:%S")
    message="$t    $1"
    echo $message | tee -a "./runlog.txt"
}



FunPrecondition(){
    if $PreconditionFlag; then
        logging "Start 128k seq write x2 for precondition"
        PIDList=()
        PIDListIndex=0
        for dev in ${DevList[@]}
        do
            TestName=128k_precondition
            fio -filename=/dev/$dev -direct=1 -iodepth=128 -thread -rw=write -ioengine=libaio -bs=128k -loops=2 -numjobs=1 -group_reporting -name=$TestName &
            PIDList[$PIDListIndex]=$!
            PIDListIndex=$(($PIDListIndex+1))
        done
        echo "Precondition PID List: ${PIDList[*]}"
        logging "waitting precondition done!"
        for pid_id in ${PIDList[@]}
        do
            logging "waitting PID: $pid_id"
            wait $pid_id
        done
        logging "All precondition done!"
    fi
}

FunRandwritePrecondition(){
    if $PreconditionFlag; then
        logging "Start 4k rand write x2 for precondition"
        PIDList=()
        PIDListIndex=0
        for dev in ${DevList[@]}
        do
			#
			TestName="4k_precondition_t${PIDListIndex}"
			fio -filename=/dev/$dev -direct=1 -bs=4k -iodepth=64 -numjobs=1 -thread -rw=randwrite -ioengine=libaio -offset=0% -size=25% -loops=2 -group_reporting -name=$TestName &
			PIDList[$PIDListIndex]=$!
            PIDListIndex=$(($PIDListIndex+1))
			#
			TestName="4k_precondition_t${PIDListIndex}"
			fio -filename=/dev/$dev -direct=1 -bs=4k -iodepth=64 -numjobs=1 -thread -rw=randwrite -ioengine=libaio -offset=25% -size=25% -loops=2 -group_reporting -name=$TestName &
			PIDList[$PIDListIndex]=$!
            PIDListIndex=$(($PIDListIndex+1))
			#
			TestName="4k_precondition_t${PIDListIndex}"
			fio -filename=/dev/$dev -direct=1 -bs=4k -iodepth=64 -numjobs=1 -thread -rw=randwrite -ioengine=libaio -offset=50% -size=25% -loops=2 -group_reporting -name=$TestName &
			PIDList[$PIDListIndex]=$!
            PIDListIndex=$(($PIDListIndex+1))
			#
			TestName="4k_precondition_t${PIDListIndex}"
			fio -filename=/dev/$dev -direct=1 -bs=4k -iodepth=64 -numjobs=1 -thread -rw=randwrite -ioengine=libaio -offset=75% -size=25% -loops=2 -group_reporting -name=$TestName &
			PIDList[$PIDListIndex]=$!
            PIDListIndex=$(($PIDListIndex+1))
        done
        echo "Precondition PID List: ${PIDList[*]}"
        logging "waitting precondition done!"
        for pid_id in ${PIDList[@]}
        do
            logging "waitting PID: $pid_id"
            wait $pid_id
        done
        logging "All precondition done!"
    fi
}


checkDir(){
    dir_path=$1
    dir_path="."
    for i in $(echo $1 | sed "s/\// /g")
    do
        if [ $i == '.' ]; then
            dir_path="."
        elif [ $i == '..' ];then
            dir_path=".."
        else
            dir_path="${dir_path}/$i"
            if [ ! -d $dir_path ];then
                mkdir $dir_path
            fi
        fi
    done
}

FunTPTest(){
    logging "start seq test"
    rw_l=("read" "write")
    for rw in ${rw_l[@]}
    do
        for numjob in ${seqJobs[@]}
        do
            for bs in ${seqBS[@]}
            do
                for qd in ${seqQD[@]}
                do
                    for dev in ${DevList[@]}
                    do
                        BasePath="./${dev}/TP/bs_${bs}"
                        checkDir $BasePath
                        json_file="${BasePath}/${rw}-${qd}-${numjob}.json"
                        TestName="${rw}-iodepth-${qd}-numjobs-${numjob}"
                        TestPath="${BasePath}/${TestName}"
                        logging "RunCMD: fio -filename=/dev/$dev -direct=1 -iodepth=$qd -thread -rw=$rw -ioengine=libaio -bs=$bs -numjobs=$numjob -runtime=$RunTimePerTest -time_based -group_reporting -name=$TestName -log_avg_msec=$log_interval -write_bw_log=$TestPath -write_lat_log=$TestPath -write_iops_log=$TestPath --output-format=json --output=$json_file"
                        fio -filename=/dev/$dev -direct=1 -iodepth=$qd -thread -rw=$rw -ioengine=libaio -bs=$bs -numjobs=$numjob -runtime=$RunTimePerTest -time_based -group_reporting -name=$TestName -log_avg_msec=$log_interval -write_bw_log=$TestPath -write_lat_log=$TestPath -write_iops_log=$TestPath --output-format=json --output=$json_file &
                    done
                    sleep $RunTimePerTest
                    sleep 3 # sleep more 3 second to wait finsihed
                done
            done
        done
    done
    echo ""
}


FuncIOPSTest(){
    logging "start random test"
    for rwmixread in ${RandRWMixRead[@]}
    do
        for numjob in ${RandJobs[@]}
        do
            for bs in ${RandBS[@]}
            do
                for qd in ${RandQD[@]}
                do
                    for dev in ${DevList[@]}
                    do
                        BasePath="./${dev}/IOPS/bs_${bs}/rwmixread${rwmixread}"
                        checkDir $BasePath
                        json_file="${BasePath}/randrw-${qd}-${numjob}.json"
                        TestName="randrw-iodepth-${qd}-numjobs-${numjob}"
                        TestPath="${BasePath}/${TestName}"
                        logging "RunCMD: fio -filename=/dev/$dev -direct=1 -ramp_time=$rand_ramp_time -iodepth=$qd -thread -rw=randrw -rwmixread=$rwmixread -ioengine=libaio -bs=$bs -numjobs=$numjob -runtime=$RunTimePerTest -time_based -group_reporting -name=$TestName -log_avg_msec=$log_interval -write_bw_log=$TestPath -write_lat_log=$TestPath -write_iops_log=$TestPath --output-format=json --output=$json_file"
                        fio -filename=/dev/$dev -direct=1 -ramp_time=$rand_ramp_time -iodepth=$qd -thread -rw=randrw -rwmixread=$rwmixread -ioengine=libaio -bs=$bs -numjobs=$numjob -runtime=$RunTimePerTest -time_based -group_reporting -name=$TestName -log_avg_msec=$log_interval -write_bw_log=$TestPath -write_lat_log=$TestPath -write_iops_log=$TestPath --output-format=json --output=$json_file &
                    done
                    sleep $RunTimePerTest
                    sleep $rand_ramp_time
                    sleep 3 # sleep more 3 second to wait finsihed
                done
            done
        done
    done
    echo ""
}

FuncLatTest(){
    logging "start Lat test"
    rw_l=("randread" "randwrite")
    for rw in ${rw_l[@]}
    do
        for numjob in ${LatJobs[@]}
        do
            for bs in ${LatBS[@]}
            do
                for qd in ${LatQD[@]}
                do
                    for dev in ${DevList[@]}
                    do
                        BasePath="./${dev}/Lat/bs_${bs}/$rw"
                        checkDir $BasePath
                        json_file="${BasePath}/${rw}-${qd}-${numjob}.json"
                        TestName="${rw}-iodepth-${qd}-numjobs-${numjob}"
                        TestPath="${BasePath}/${TestName}"
                        logging "RunCMD: fio -filename=/dev/$dev -direct=1 -iodepth=$qd -thread -rw=$rw -ioengine=libaio -bs=$bs -numjobs=$numjob -runtime=$RunTimePerTest -time_based -group_reporting -name=$TestName -log_avg_msec=$log_interval -write_bw_log=$TestPath -write_lat_log=$TestPath -write_iops_log=$TestPath --output-format=json --output=$json_file"
                        fio -filename=/dev/$dev -direct=1 -iodepth=$qd -thread -rw=$rw -ioengine=libaio -bs=$bs -numjobs=$numjob -runtime=$RunTimePerTest -time_based -group_reporting -name=$TestName -log_avg_msec=$log_interval -write_bw_log=$TestPath -write_lat_log=$TestPath -write_iops_log=$TestPath --output-format=json --output=$json_file &
                    done
                    sleep $RunTimePerTest
                    sleep 3 # sleep more 3 second to wait finsihed
                done
            done
        done
    done
    echo ""
}


FuncRunMixedFIO(){
	logging "$VERSION"
    logging ""
    FunPrecondition
    for test_case in ${TestCase[@]}
    do
        if [ $test_case == "tp" ]; then
            FunTPTest
        elif [ $test_case == "iops" ]; then
            # 4k rand write precondition
            FunRandwritePrecondition
            # run test case
            FuncIOPSTest
        elif [ $test_case == "lat" ]; then
            FuncLatTest
        else
            echo "unkonown test case."
        fi
    done
}


function comma_to_array()
{
for i in $(echo $1 | sed "s/,/ /g")
do
    echo "$i"
done
}

### main run here
## default test case
TestCase=("tp" "iops" "lat")
PreconditionFlag=true
## handle parameters
while getopts "d:t:s:pvh" arg
do
    case $arg in 
    v)
        echo "$VERSION"
	    exit 0
	    ;;
	d)
        ## handle dev list
        DevList=($(comma_to_array $OPTARG))
        logging "Device in Test: ${DevList[*]}"
        logging ""
	    ;;
    s)
        TestCase=($(comma_to_array $OPTARG))
        logging "Test Case: ${TestCase[*]}"
        logging ""
        ;;
    t)
        SetFIOWorkload $OPTARG
	    ;; 
	p)
        logging "Set disable precondition"
        PreconditionFlag=false  # disable precondition
	    ;; 
	h)
        FunEchoHelp
	    exit 0
	    ;; 
	*)
	    FunEchoHelp
	    exit 0
    ;;
    esac
done
## run test
if [[ ! -n $DevList ]]; then
    echo "Need input device."
    echo ""
    FunEchoHelp
    exit 1
fi
if [[ ! -n $TestCase ]]; then
    echo "Need Test case."
    echo ""
    FunEchoHelp
    exit 1
fi

FuncRunMixedFIO
