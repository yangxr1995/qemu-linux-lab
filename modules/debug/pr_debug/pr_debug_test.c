/*
 * 1. 确保打开debugfs模块
 * 2. pr_debug的行为 :
 *    1) 没有开启CONFIG_DYNAMIC_DEBUG模块，且没有-DDEBUG
 *       pr_debug 为 空
 *    2) 没有开启CONFIG_DYNAMIC_DEBUG模块，但开启-DDEBUG 
 *    	 pr_debug 相当于 printk(KERN_DEBUG 
 *    3) 开启CONFIG_DYNAMIC_DEBUG模块
 *    	 pr_debug 相当于 dynamic_pr_debug
 *
 * 3. dynamic_pr_debug
 *    必须指定开启对应文件的信息打印，才会输出。
 *    如何开启?
 *	  1) 搜索文件
 *	  / # cat /sys/kernel/debug/dynamic_debug/control  |grep "pr_dbg"
 *	  	/root/qemu-linux-lab/modules/test.c:10 [test]timer_handler =p "pr_dbg: This is pr_init func.\012"
 *	  2) 开启打印
 *	  	开启某个文件的打印信息
 *	    / # echo "file test.c +p" > /sys/kernel/debug/dynamic_debug/control
 *		开启某个module的打印信息
 *	    / # echo "module $module-name +p" > /sys/kernel/debug/dynamic_debug/control
 *	  3) 关闭打印
 *	    / # echo "module $module-name -p" > /sys/kernel/debug/dynamic_debug/control
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/printk.h>

static struct timer_list timer = {0};


void timer_handler(struct timer_list *t)
{
    pr_debug("pr_dbg: This is pr_init func.\n");
    mod_timer(&timer, jiffies+msecs_to_jiffies(5000));
}

static int pr_test_init(void)
{
    timer_setup(&timer, timer_handler, 0);
    timer.expires = jiffies + 5 * HZ;
    add_timer(&timer);

    return 0;
}

static int pr_init(void)
{
    pr_test_init();
    printk("pr_debug test init finished.\n");

    return 0;
}

static void pr_exit(void)
{
    del_timer(&timer);
    printk("pr_debug test exit finished.\n");
}

module_init(pr_init);
module_exit(pr_exit);
MODULE_LICENSE("GPL");
MODULE_AUTHOR("Zackary.Liu");
